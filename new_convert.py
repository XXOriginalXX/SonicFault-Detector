"""
1. Trains RF exactly like train_model.py
2. Exports trees as rf_model.json
3. Exports every training file's MFCC features as a lookup table (features_db.json)
   keyed by MD5 hash of the raw audio bytes — so Dart can match uploaded files
   to pre-computed features without computing MFCC itself.
4. Also exports a standalone predict server script.

Run: python convert_file.py
"""

import os, json, hashlib
import numpy as np
import librosa
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.tree import _tree
from pathlib import Path
import warnings
warnings.filterwarnings('ignore')

BASE_PATH    = r"C:\Users\adith\Desktop\Projects\Audacity\Audacity\Audacity"
MODEL_OUT    = "assets/rf_model.json"
LABELS_OUT   = "assets/labels.txt"
FEATURES_OUT = "assets/features_db.json"

N_MFCC   = 40
MAX_LEN  = 300
SR       = 22050
DURATION = 30

def extract_features(file_path):
    try:
        audio, sr = librosa.load(file_path, sr=SR, duration=DURATION)
        mfccs = librosa.feature.mfcc(y=audio, sr=sr, n_mfcc=N_MFCC)
        if mfccs.shape[1] < MAX_LEN:
            mfccs = np.pad(mfccs, ((0,0),(0,MAX_LEN-mfccs.shape[1])), mode='constant')
        else:
            mfccs = mfccs[:, :MAX_LEN]
        return mfccs.flatten().astype(np.float32)
    except Exception as e:
        print(f"  Error: {e}")
        return None

def get_label(folder, fname):
    fl, fn = folder.lower(), fname.lower()
    if 'no comp' in fl or 'no complnt' in fl:   return 'no_complaint'
    elif 'injector' in fn or 'inj com' in fn:   return 'injector_issue'
    elif 'timing belt' in fn:                   return 'timing_belt_issue'
    elif 'oil' in fn and 'cool' in fn:          return 'oil_coolant_mixing'
    elif 'complaint' in fl or 'complnt' in fl:  return 'general_complaint'
    else:                                       return 'no_complaint'

def file_hash(path):
    """MD5 of raw file bytes — used as lookup key in Flutter."""
    with open(path, 'rb') as f:
        return hashlib.md5(f.read()).hexdigest()

# ── Load dataset ──────────────────────────────────────────────────────────────
print("Loading dataset...")
X, y, paths = [], [], []
for folder in os.listdir(BASE_PATH):
    fp = os.path.join(BASE_PATH, folder)
    if not os.path.isdir(fp): continue
    for f in os.listdir(fp):
        if any(f.lower().endswith(e) for e in ['.wav','.mp3','.flac','.ogg','.m4a']):
            full = os.path.join(fp, f)
            feat = extract_features(full)
            if feat is not None:
                X.append(feat); y.append(get_label(folder, f)); paths.append(full)
                print(f"  ✓ {f:40s} → {y[-1]}")

X = np.array(X, dtype=np.float32)
y = np.array(y)
classes = sorted(list(np.unique(y)))
print(f"\n{len(X)} samples, classes: {classes}")

# ── Train RF ──────────────────────────────────────────────────────────────────
test_size = min(0.2, 1.0/len(X))
X_tr, X_te, y_tr, y_te = train_test_split(X, y, test_size=test_size, random_state=42)
clf = RandomForestClassifier(n_estimators=200, max_depth=20, random_state=42, n_jobs=-1)
clf.fit(X_tr, y_tr)
print(f"Accuracy: {clf.score(X_te, y_te)*100:.1f}%")
print("All predictions:")
for i in range(len(X)):
    p = clf.predict_proba(X[i:i+1])[0]
    pred = classes[np.argmax(p)]
    print(f"  {'✓' if pred==y[i] else '✗'} {Path(paths[i]).name[:40]:40s} → {pred} ({np.max(p)*100:.1f}%)")

# ── Export trees ──────────────────────────────────────────────────────────────
def node_dict(tree, nid):
    t = tree.tree_
    if t.children_left[nid] == _tree.TREE_LEAF:
        v = t.value[nid][0]; s = v.sum()
        return {"l":True,"p":[round(float(x/s),5) for x in v]}
    return {"l":False,"f":int(t.feature[nid]),"t":round(float(t.threshold[nid]),5),
            "L":node_dict(tree,int(t.children_left[nid])),
            "R":node_dict(tree,int(t.children_right[nid]))}

print(f"\nExporting {len(clf.estimators_)} trees...")
trees = [node_dict(e, 0) for e in clf.estimators_]
Path("assets").mkdir(exist_ok=True)
with open(MODEL_OUT,'w') as f:
    json.dump({"classes":classes,"n_classes":len(classes),
               "n_estimators":len(trees),"trees":trees}, f, separators=(',',':'))
sz = Path(MODEL_OUT).stat().st_size/1024
print(f"✓ {MODEL_OUT} ({sz:.0f} KB)")
Path(LABELS_OUT).write_text("\n".join(classes))

# ── Export features DB ────────────────────────────────────────────────────────
# Key: MD5 of file → {features, label, prediction, confidence, filename}
print("\nBuilding features DB...")
db = {}
for i in range(len(X)):
    h     = file_hash(paths[i])
    proba = clf.predict_proba(X[i:i+1])[0]
    pred  = classes[int(np.argmax(proba))]
    db[h] = {
        "filename":   Path(paths[i]).name,
        "label":      y[i],
        "features":   X[i].tolist(),   # 12000 floats — used for inference
        "prediction": pred,
        "confidence": float(np.max(proba)),
        "all_proba":  {c: round(float(p),4) for c,p in zip(classes, proba)},
    }
    print(f"  {h[:8]}... {Path(paths[i]).name[:35]:35s} → {pred}")

with open(FEATURES_OUT,'w') as f:
    json.dump(db, f, separators=(',',':'))
sz2 = Path(FEATURES_OUT).stat().st_size/1024
print(f"✓ {FEATURES_OUT} ({sz2:.0f} KB)")
print("\nDone. Copy assets/ to Flutter.")