import numpy as np
import librosa
import joblib
import sys

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
        print(f"Error processing audio: {e}")
        return None

def predict_complaint(audio_path, model_path='vehicle_complaint_model.pkl'):
    try:
        clf = joblib.load(model_path)
        print(f"Model loaded from {model_path}")
    except FileNotFoundError:
        print("Error: Model file not found. Please run train_model.py first.")
        return
    
    print(f"\nProcessing audio: {audio_path}")
    features = extract_features(audio_path)
    
    if features is None:
        print("Failed to extract features from audio.")
        return
    
    features = features.reshape(1, -1)
    prediction = clf.predict(features)
    probabilities = clf.predict_proba(features)[0]
    
    print("\n" + "="*50)
    print("PREDICTION RESULT")
    print("="*50)
    print(f"Detected Issue: {prediction[0].upper().replace('_', ' ')}")
    print("\nConfidence Scores:")
    for label, prob in zip(clf.classes_, probabilities):
        print(f"  {label.replace('_', ' ').title()}: {prob*100:.2f}%")
    print("="*50)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python test_model.py <audio_file_path>")
        print("Example: python test_model.py test_audio.aup3")
    else:
        audio_file = sys.argv[1]
        predict_complaint(audio_file)