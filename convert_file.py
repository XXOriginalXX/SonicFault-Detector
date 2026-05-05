import os
import sqlite3
import wave
import numpy as np
import librosa
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.utils.class_weight import compute_class_weight
from collections import Counter
import joblib
import warnings

warnings.filterwarnings('ignore')

BASE_PATH = r"C:\Users\adith\Desktop\Projects\Audacity\Audacity\Audacity"

# ─────────────────────────────────────────────────────────────────
# EXACT folder name → label mapping (every folder in your dataset)
# ─────────────────────────────────────────────────────────────────
FOLDER_LABEL_MAP = {
    # LOW COMPRESSION
    "9-1-2026 bolero low compression issue": "low_compression",

    # TURBO LEAK
    "harrier turbo leak issue":              "turbo_leak",

    # BELT ISSUE (serpentine/drive belt)
    "scorpio belt issue 9-1-2026":           "belt_issue",
    "xuv belt issue":                        "belt_issue",

    # TIMING BELT ISSUE
    "ford fiesta":                           "timing_belt_issue",

    # LOCK / CYLINDER ISSUE
    "xuv 300 lock cylinder issue":           "lock_issue",

    # INJECTOR ISSUE
    "evalia":                                "injector_issue",
    "tuv 300":                               "injector_issue",

    # OIL COOLANT MIXING
    "xuv 500 complnt":                       "oil_coolant_mixing",

    # GENERAL COMPLAINT (unspecified / mixed symptoms)
    "amaze complaint":                       "general_issue",

    # NO ISSUE
    "ashokleyland lorry no issue":           "no_issue",
    "bolero no issue":                       "no_issue",
    "mobilio no comp":                       "no_issue",
    "bolero no complnt":                     "no_issue",
    "swift no complnt":                      "no_issue",
    "thar no compl":                         "no_issue",
    "volkswagen jet no complnt":             "no_issue",
    "amaze dtec":                            "no_issue",
    "volvo":                                 "no_issue",
    "xuv300":                                "no_issue",
    "dezire 1.3":                            "no_issue",
    "izuzu":                                 "no_issue",
    "nissan sunny":                          "no_issue",
    "endevaour":                             "no_issue",
}


def get_label_from_folder(folder_name):
    key = folder_name.strip().lower()
    label = FOLDER_LABEL_MAP.get(key)
    if label is None:
        print(f"  [UNMATCHED — SKIPPED] '{folder_name}'")
    return label


def extract_audio_from_aup3(aup3_file, output_wav):
    try:
        conn = sqlite3.connect(aup3_file)
        cursor = conn.cursor()

        cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
        tables = [t[0] for t in cursor.fetchall()]

        target_table = None
        if 'sampleblocks' in tables:
            target_table = 'sampleblocks'
            id_col      = 'blockid'
            data_col    = 'samples'
        elif 'sample_blocks' in tables:
            target_table = 'sample_blocks'
            id_col      = 'block_id'
            data_col    = 'sample_data'

        if not target_table:
            print(f"  [!] Unknown DB structure: {os.path.basename(aup3_file)}")
            conn.close()
            return False

        cursor.execute(f"SELECT {data_col} FROM {target_table} ORDER BY {id_col}")
        blocks = cursor.fetchall()

        audio_data = []
        for block in blocks:
            blob = block[0]
            if blob and isinstance(blob, bytes):
                audio_data.extend(np.frombuffer(blob, dtype=np.float32))

        conn.close()

        if not audio_data:
            return False

        audio_array = np.clip(np.array(audio_data), -1.0, 1.0)
        audio_int16 = (audio_array * 32767).astype(np.int16)

        with wave.open(output_wav, 'wb') as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(44100)
            wf.writeframes(audio_int16.tobytes())

        return True
    except Exception as e:
        print(f"  Conversion Error: {os.path.basename(aup3_file)}: {e}")
        return False


def extract_features_augmented(file_path, n_mfcc=40, max_len=300):
    """4 variants per file: original, noise, pitch+1, pitch-1"""
    results = []
    try:
        y_audio, sr = librosa.load(file_path, sr=22050, duration=10)
        variants = [
            y_audio,
            y_audio + 0.005 * np.random.randn(len(y_audio)),
            librosa.effects.pitch_shift(y_audio, sr=sr, n_steps=1),
            librosa.effects.pitch_shift(y_audio, sr=sr, n_steps=-1),
        ]
        for v in variants:
            mfccs = librosa.feature.mfcc(y=v, sr=sr, n_mfcc=n_mfcc)
            if mfccs.shape[1] < max_len:
                mfccs = np.pad(mfccs, ((0, 0), (0, max_len - mfccs.shape[1])), mode='constant')
            else:
                mfccs = mfccs[:, :max_len]
            results.append(mfccs.flatten())
    except Exception as e:
        print(f"  Feature extraction failed: {file_path}: {e}")
    return results


def main():
    X, y = [], []
    seen_wav_paths = set()

    print("Step 1: Converting .aup3 files and extracting features...\n")

    for root, dirs, files in os.walk(BASE_PATH):
        folder_name = os.path.basename(root)
        label = get_label_from_folder(folder_name)

        if label is None:
            continue

        for file in files:
            if not file.endswith('.aup3'):
                continue

            aup3_path = os.path.join(root, file)
            wav_path  = aup3_path.replace('.aup3', '.wav')

            if wav_path in seen_wav_paths:
                continue
            seen_wav_paths.add(wav_path)

            if not os.path.exists(wav_path):
                success = extract_audio_from_aup3(aup3_path, wav_path)
                if success:
                    print(f"  [CONVERTED] {file} → {label}")
                else:
                    print(f"  [FAILED]    {file}")
                    continue
            else:
                print(f"  [EXISTS]    {file} → {label}")

            feats = extract_features_augmented(wav_path)
            for feat in feats:
                X.append(feat)
                y.append(label)

    if len(X) < 2:
        print("\nError: Not enough features extracted.")
        return

    label_counts = Counter(y)
    print(f"\n{'─'*45}")
    print(f"Total samples (after augmentation): {len(X)}")
    print("Class distribution:")
    for lbl, count in sorted(label_counts.items()):
        flag = " ⚠ add more recordings" if count < 8 else ""
        print(f"  {lbl}: {count} samples{flag}")

    X_arr = np.array(X)
    y_arr = np.array(y)

    classes = np.unique(y_arr)
    weights = compute_class_weight(class_weight='balanced', classes=classes, y=y_arr)
    class_weight_dict = dict(zip(classes, weights))

    print(f"\nStep 2: Training model...")

    min_count = min(label_counts.values())
    if min_count >= 2:
        X_train, X_test, y_train, y_test = train_test_split(
            X_arr, y_arr, test_size=0.2, random_state=42, stratify=y_arr
        )
    else:
        print("[WARNING] A class has only 1 sample — skipping stratified split")
        X_train, X_test, y_train, y_test = train_test_split(
            X_arr, y_arr, test_size=0.2, random_state=42
        )

    model = RandomForestClassifier(
        n_estimators=300,
        class_weight=class_weight_dict,
        max_depth=25,
        min_samples_split=2,
        min_samples_leaf=1,
        random_state=42,
        n_jobs=-1
    )
    model.fit(X_train, y_train)

    train_acc = model.score(X_train, y_train)
    test_acc  = model.score(X_test,  y_test)
    print(f"Train accuracy : {train_acc:.2%}")
    print(f"Test  accuracy : {test_acc:.2%}")

    joblib.dump(model, 'vehicle_complaint_model.pkl')
    print(f"\nSUCCESS: Model saved → vehicle_complaint_model.pkl")
    print(f"Classes: {list(classes)}")


if __name__ == "__main__":
    main()