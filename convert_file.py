"""
Re-exports the model AND saves a test feature vector so we can verify
the Dart MFCC matches librosa exactly.

Run: python convert_file.py
Outputs:
  assets/model.tflite
  assets/labels.txt
  assets/test_features.json   ← first sample's features + expected label
"""

import os, json
import numpy as np
import librosa
import joblib
import flatbuffers
from pathlib import Path
from sklearn.linear_model import LogisticRegression
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split
import warnings
warnings.filterwarnings('ignore')

BASE_PATH  = r"C:\Users\adith\Desktop\Projects\Audacity\Audacity\Audacity"
TFLITE_OUT = "assets/model.tflite"
LABELS_OUT = "assets/labels.txt"
TEST_OUT   = "assets/test_features.json"

N_MFCC    = 40
MAX_LEN   = 300
SR        = 22050
INPUT_DIM = N_MFCC * MAX_LEN

# ── Feature extraction matching librosa EXACTLY ───────────────────────────────
def extract_features(file_path):
    try:
        # duration=10 matches the backend main.py
        audio, sr = librosa.load(file_path, sr=SR, duration=10)
        mfccs = librosa.feature.mfcc(y=audio, sr=sr, n_mfcc=N_MFCC)
        if mfccs.shape[1] < MAX_LEN:
            mfccs = np.pad(mfccs, ((0,0),(0, MAX_LEN - mfccs.shape[1])), mode='constant')
        else:
            mfccs = mfccs[:, :MAX_LEN]
        return mfccs.flatten().astype(np.float32)
    except Exception as e:
        print(f"  ERROR {file_path}: {e}")
        return None

def get_label(folder, fname):
    fl, fn = folder.lower(), fname.lower()
    if 'no comp' in fl or 'no complnt' in fl:   return 'no_complaint'
    elif 'injector' in fn or 'inj com' in fn:   return 'injector_issue'
    elif 'timing belt' in fn:                   return 'timing_belt_issue'
    elif 'oil' in fn and 'cool' in fn:          return 'oil_coolant_mixing'
    elif 'complaint' in fl or 'complnt' in fl:  return 'general_complaint'
    else:                                       return 'no_complaint'

# ── Load dataset ──────────────────────────────────────────────────────────────
print("Loading dataset...")
X, y, file_paths = [], [], []
for folder in os.listdir(BASE_PATH):
    fp = os.path.join(BASE_PATH, folder)
    if not os.path.isdir(fp): continue
    for f in os.listdir(fp):
        if Path(f).suffix.lower() in {'.wav','.mp3','.flac','.ogg','.m4a'}:
            feat = extract_features(os.path.join(fp, f))
            if feat is not None:
                X.append(feat)
                y.append(get_label(folder, f))
                file_paths.append(os.path.join(fp, f))

X = np.array(X, dtype=np.float32)
y = np.array(y)
print(f"Loaded {len(X)} samples")
print(f"Labels: {dict(zip(*np.unique(y, return_counts=True)))}")

# ── Train LR ──────────────────────────────────────────────────────────────────
scaler   = StandardScaler()
X_scaled = scaler.fit_transform(X)

counts   = np.bincount(np.unique(y, return_inverse=True)[1])
stratify = y if counts.min() > 1 else None
X_tr, X_te, y_tr, y_te = train_test_split(
    X_scaled, y, test_size=0.2, random_state=42, stratify=stratify)

print("Training LogisticRegression...")
lr = LogisticRegression(max_iter=2000, C=1.0, solver='lbfgs',
                        multi_class='multinomial', random_state=42, n_jobs=-1)
lr.fit(X_tr, y_tr)
print(f"Accuracy: {lr.score(X_te, y_te)*100:.1f}%")

classes   = list(lr.classes_)
n_classes = len(classes)
print(f"Classes: {classes}")

# ── Fold scaler into weights ──────────────────────────────────────────────────
mean     = scaler.mean_.astype(np.float32)
std      = np.sqrt(scaler.var_).astype(np.float32) + 1e-8
W_lr     = lr.coef_.T.astype(np.float32)
b_lr     = lr.intercept_.astype(np.float32)
W_folded = W_lr / std[:, None]
b_folded = b_lr - (mean / std) @ W_lr
W_tflite = W_folded.T.astype(np.float32)
b_tflite = b_folded.astype(np.float32)

# ── Save test features JSON for Dart verification ─────────────────────────────
# Pick one sample of each class for testing
test_samples = {}
for i, label in enumerate(y):
    if label not in test_samples:
        # Raw MFCC features (before scaling) — this is what Dart should produce
        test_samples[label] = {
            'features': X[i].tolist(),
            'expected_label': label,
            'expected_proba': lr.predict_proba(X_scaled[i:i+1])[0].tolist(),
            'file': file_paths[i],
        }
    if len(test_samples) == n_classes:
        break

Path("assets").mkdir(exist_ok=True)
with open(TEST_OUT, 'w') as f:
    json.dump({'classes': classes, 'samples': test_samples}, f)
print(f"Saved test features → {TEST_OUT}")

# ── Build TFLite flatbuffer ───────────────────────────────────────────────────
def build_tflite(W, b, in_dim, n_out):
    B = flatbuffers.Builder(16 * 1024 * 1024)

    # All children MUST be built before their parent StartObject is called
    def bvec(data):
        B.StartVector(1, len(data), 1)
        for byte in reversed(data):
            B.PrependByte(byte)
        return B.EndVector()

    def ivec(ints):
        B.StartVector(4, len(ints), 4)
        for v in reversed(ints):
            B.PrependInt32(v)
        return B.EndVector()

    def make_buffer(payload):
        dv = bvec(payload)          # build child first
        B.StartObject(2)
        B.PrependUOffsetTRelativeSlot(1, dv, 0)
        return B.EndObject()

    def make_tensor(name, shape, buf_idx, typ=1):
        ns = B.CreateString(name.encode())  # build children first
        sv = ivec(shape)
        B.StartObject(6)
        B.PrependUOffsetTRelativeSlot(0, ns, 0)
        B.PrependUOffsetTRelativeSlot(1, sv, 0)
        B.PrependInt32Slot(2, typ, 0)
        B.PrependInt32Slot(3, buf_idx, 0)
        return B.EndObject()

    def make_opcode(code):
        B.StartObject(4)
        B.PrependInt32Slot(0, code, 0)
        return B.EndObject()

    def make_op(idx, ins, outs):
        iv = ivec(ins)              # build children first
        ov = ivec(outs)
        B.StartObject(6)
        B.PrependInt32Slot(0, idx, 0)
        B.PrependUOffsetTRelativeSlot(1, iv, 0)
        B.PrependUOffsetTRelativeSlot(2, ov, 0)
        return B.EndObject()

    # ── Build bottom-up (leaves first) ───────────────────────────────────────

    # 1. Buffers
    buf0 = make_buffer(b'')
    buf1 = make_buffer(W.tobytes())
    buf2 = make_buffer(b.tobytes())
    buf3 = make_buffer(b'')
    buf4 = make_buffer(b'')
    buf5 = make_buffer(b'')
    bufs = ivec([buf0, buf1, buf2, buf3, buf4, buf5])

    # 2. Tensors
    t0 = make_tensor("input",   [1, in_dim],    3)
    t1 = make_tensor("weights", [n_out, in_dim], 1)
    t2 = make_tensor("bias",    [n_out],         2)
    t3 = make_tensor("fc_out",  [1, n_out],      4)
    t4 = make_tensor("output",  [1, n_out],      5)
    tens = ivec([t0, t1, t2, t3, t4])

    # 3. Opcodes: FULLY_CONNECTED=9, SOFTMAX=25
    oc0 = make_opcode(9)
    oc1 = make_opcode(25)
    ocs = ivec([oc0, oc1])

    # 4. Operators
    op0 = make_op(0, [0, 1, 2], [3])
    op1 = make_op(1, [3],       [4])
    ops = ivec([op0, op1])

    # 5. Subgraph inputs/outputs — build BEFORE StartObject
    sg_ins  = ivec([0])
    sg_outs = ivec([4])

    # 6. Subgraph
    B.StartObject(6)
    B.PrependUOffsetTRelativeSlot(0, tens,    0)
    B.PrependUOffsetTRelativeSlot(1, ops,     0)
    B.PrependUOffsetTRelativeSlot(2, sg_ins,  0)
    B.PrependUOffsetTRelativeSlot(3, sg_outs, 0)
    sg   = B.EndObject()
    sgs  = ivec([sg])

    # 7. Description string
    desc = B.CreateString(b"sonic_fault_lr_v2")

    # 8. Root model
    B.StartObject(8)
    B.PrependInt32Slot(0, 3, 0)
    B.PrependUOffsetTRelativeSlot(1, ocs,  0)
    B.PrependUOffsetTRelativeSlot(2, sgs,  0)
    B.PrependUOffsetTRelativeSlot(3, desc, 0)
    B.PrependUOffsetTRelativeSlot(4, bufs, 0)
    root = B.EndObject()

    B.Finish(root)
    raw = bytes(B.Output())
    return raw[:4] + b'TFL3' + raw[8:]

print("Building TFLite...")
tflite_bytes = build_tflite(W_tflite, b_tflite, INPUT_DIM, n_classes)
Path(TFLITE_OUT).write_bytes(tflite_bytes)
Path(LABELS_OUT).write_text("\n".join(classes))

print(f"✓ {TFLITE_OUT}  ({len(tflite_bytes)/1024:.1f} KB)")
print(f"✓ {LABELS_OUT}  {classes}")

# ── Verify all samples ────────────────────────────────────────────────────────
print("\nVerifying all samples with folded weights:")
correct = 0
for i in range(len(X)):
    raw     = X[i:i+1]
    logits  = raw @ W_folded + b_folded
    exp     = np.exp(logits - logits.max())
    probs   = (exp / exp.sum()).flatten()
    pred    = classes[np.argmax(probs)]
    correct += (pred == y[i])
    status  = '✓' if pred == y[i] else '✗'
    print(f"  {status} {Path(file_paths[i]).name[:40]:40s} → {pred} ({np.max(probs)*100:.1f}%)")

print(f"\nFolded weights accuracy: {correct}/{len(X)} = {correct/len(X)*100:.1f}%")
print("\nDone! Copy assets/ into Flutter project and run: flutter pub get && flutter run")