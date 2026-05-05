import os
import sqlite3
import wave
import numpy as np
import librosa
from prometheus_client import Counter
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
import joblib
import warnings

warnings.filterwarnings('ignore')

BASE_PATH = r"C:\Users\adith\Desktop\Projects\Audacity\Audacity\Audacity"

def extract_audio_from_aup3(aup3_file, output_wav):
    """Extracts raw blobs from Audacity SQLite DB with table name fallback."""
    try:
        conn = sqlite3.connect(aup3_file)
        cursor = conn.cursor()
        
        # Check which table name exists in this specific file
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
        tables = [t[0] for t in cursor.fetchall()]
        
        target_table = None
        if 'sampleblocks' in tables:
            target_table = 'sampleblocks'
            id_col = 'blockid'
            data_col = 'samples'
        elif 'sample_blocks' in tables:
            target_table = 'sample_blocks'
            id_col = 'block_id'
            data_col = 'sample_data'
            
        if not target_table:
            print(f"  [!] Unknown database structure in {os.path.basename(aup3_file)}")
            conn.close()
            return False
        
        # Fetch the data using the identified correct column names
        cursor.execute(f"SELECT {data_col} FROM {target_table} ORDER BY {id_col}")
        blocks = cursor.fetchall()
        
        audio_data = []
        for block in blocks:
            blob = block[0]
            if blob and isinstance(blob, bytes):
                samples = np.frombuffer(blob, dtype=np.float32)
                audio_data.extend(samples)
        
        conn.close()
        
        if not audio_data:
            return False

        # Convert 32-bit float to 16-bit PCM for WAV
        audio_array = np.clip(np.array(audio_data), -1.0, 1.0)
        audio_int16 = (audio_array * 32767).astype(np.int16)
        
        with wave.open(output_wav, 'wb') as wav_file:
            wav_file.setnchannels(1)
            wav_file.setsampwidth(2)
            wav_file.setframerate(44100)
            wav_file.writeframes(audio_int16.tobytes())
            
        return True
    except Exception as e:
        print(f"  Conversion Error on {os.path.basename(aup3_file)}: {e}")
        return False

def get_label_from_path(folder_name):
    fn = folder_name.lower()
    # Check 'no issue' FIRST before any issue-specific keywords
    if 'no issue' in fn or 'no comp' in fn:
        return 'no_issue'
    # 'lock cylinder' must be checked before 'cylinder' alone
    if 'lock' in fn:
        return 'lock_issue'
    if 'turbo' in fn:
        return 'turbo_leak'
    if 'belt' in fn:
        return 'belt_issue'
    # 'low compression' and plain 'compression' both map here
    if 'compression' in fn or 'cylinder' in fn:
        return 'low_compression'
    return 'general_issue'

def extract_features(file_path, n_mfcc=40, max_len=300):
    try:
        y, sr = librosa.load(file_path, sr=22050, duration=10)
        mfccs = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=n_mfcc)
        if mfccs.shape[1] < max_len:
            mfccs = np.pad(mfccs, ((0, 0), (0, max_len - mfccs.shape[1])), mode='constant')
        else:
            mfccs = mfccs[:, :max_len]
        return mfccs.flatten()  # Shape: (12000,)
    except:
        return None

def main():
    X, y = [], []
    print("Step 1: Converting files and extracting features...")
    
    for root, dirs, files in os.walk(BASE_PATH):
        folder_name = os.path.basename(root)
        label = get_label_from_path(folder_name)
        
        for file in files:
            if file.endswith('.aup3'):
                aup3_path = os.path.join(root, file)
                wav_path = aup3_path.replace('.aup3', '.wav')
                
                # Force conversion if previous attempt failed/WAV is missing
                if not os.path.exists(wav_path):
                    if extract_audio_from_aup3(aup3_path, wav_path):
                        print(f" [SUCCESS] Converted: {file}")
                
                if os.path.exists(wav_path):
                    feat = extract_features(wav_path)
                    if feat is not None:
                        X.append(feat)
                        y.append(label)

    if len(X) < 2:
        print("Error: No features extracted.")
        return

    print(f"\nStep 2: Training model on {len(X)} samples...")
    from collections import Counter

    label_counts = Counter(y)
    print("\nClass distribution:")
    for label, count in sorted(label_counts.items()):
        print(f"  {label}: {count} samples")
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    
    model = RandomForestClassifier(n_estimators=100, random_state=42)
    model.fit(X_train, y_train)
    
    joblib.dump(model, 'vehicle_complaint_model.pkl')
    print(f"\nSUCCESS: Model saved with {len(X)} samples across classes: {np.unique(y)}")

if __name__ == "__main__":
    main()