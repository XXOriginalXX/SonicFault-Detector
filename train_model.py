import os
import numpy as np
import librosa
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, confusion_matrix
import joblib
import warnings
warnings.filterwarnings('ignore')

BASE_PATH = r"C:\Users\adith\Desktop\Projects\Audacity\Audacity\Audacity"

def extract_features(file_path, n_mfcc=40, max_len=300):
    try:
        audio, sr = librosa.load(file_path, sr=22050, duration=30)
        mfccs = librosa.feature.mfcc(y=audio, sr=sr, n_mfcc=n_mfcc)
        
        if mfccs.shape[1] < max_len:
            mfccs = np.pad(mfccs, ((0, 0), (0, max_len - mfccs.shape[1])), mode='constant')
        else:
            mfccs = mfccs[:, :max_len]
        
        return mfccs.flatten()
    except Exception as e:
        print(f"Error processing {file_path}: {e}")
        return None

def get_label_from_path(folder_name, file_name):
    folder_lower = folder_name.lower()
    file_lower = file_name.lower()
    
    if 'no comp' in folder_lower or 'no complnt' in folder_lower:
        return 'no_complaint'
    elif 'injector' in file_lower or 'inj com' in file_lower:
        return 'injector_issue'
    elif 'timing belt' in file_lower:
        return 'timing_belt_issue'
    elif 'oil' in file_lower and 'cool' in file_lower:
        return 'oil_coolant_mixing'
    elif 'complaint' in folder_lower or 'complnt' in folder_lower:
        return 'general_complaint'
    else:
        return 'no_complaint'

def load_dataset():
    X, y = [], []
    audio_extensions = ['.wav', '.mp3', '.flac', '.ogg', '.m4a']
    
    for folder in os.listdir(BASE_PATH):
        folder_path = os.path.join(BASE_PATH, folder)
        if not os.path.isdir(folder_path):
            continue
        
        print(f"Processing folder: {folder}")
        
        for file in os.listdir(folder_path):
            if any(file.lower().endswith(ext) for ext in audio_extensions):
                file_path = os.path.join(folder_path, file)
                features = extract_features(file_path)
                
                if features is not None:
                    label = get_label_from_path(folder, file)
                    X.append(features)
                    y.append(label)
                    print(f"  Loaded: {file} -> {label}")
    
    return np.array(X), np.array(y)

print("="*60)
print("VEHICLE COMPLAINT DETECTION - TRAINING")
print("="*60)
print("\nLooking for audio files (.wav, .mp3, .flac, .ogg, .m4a)...")
print("NOTE: .aup3 files cannot be read. Please export them first.\n")

X, y = load_dataset()

if len(X) == 0:
    print("\n" + "="*60)
    print("ERROR: No audio files found!")
    print("="*60)
    print("\nYour .aup3 files need to be exported to WAV/MP3 format.")
    print("\nSteps to fix:")
    print("1. Open each .aup3 file in Audacity")
    print("2. File → Export → Export Audio")
    print("3. Choose WAV or MP3 format")
    print("4. Save in the same folder structure")
    print("5. Re-run this training script")
    print("\nAlternatively, use Audacity's Macro feature for batch export.")
    exit(1)

print(f"\nDataset loaded: {len(X)} samples")
print(f"Label distribution: {dict(zip(*np.unique(y, return_counts=True)))}")

if len(X) < 2:
    print("\nError: Need at least 2 samples to train. Please add more audio files.")
    exit(1)

test_size = min(0.2, 1.0 / len(X))
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=test_size, random_state=42)

print("\nTraining Random Forest classifier...")
clf = RandomForestClassifier(n_estimators=200, max_depth=20, random_state=42, n_jobs=-1)
clf.fit(X_train, y_train)

y_pred = clf.predict(X_test)
print("\n" + "="*60)
print("TRAINING COMPLETE")
print("="*60)
print(f"\nTest Accuracy: {clf.score(X_test, y_test)*100:.2f}%")
print("\nClassification Report:")
print(classification_report(y_test, y_pred))

joblib.dump(clf, 'vehicle_complaint_model.pkl')
print("\nModel saved as 'vehicle_complaint_model.pkl'")
print("\nRECOMMENDATION:")
print("Random Forest doesn't use epochs. For deep learning (CNN),")
print("recommend: 50-100 epochs with early stopping.")