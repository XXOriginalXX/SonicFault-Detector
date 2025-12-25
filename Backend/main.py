from fastapi import FastAPI, File, UploadFile, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
import numpy as np
import librosa
import joblib
import io
import json
from typing import Dict

app = FastAPI(title="Vehicle Complaint Detection API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Load model at startup
try:
    model = joblib.load('vehicle_complaint_model.pkl')
    print("Model loaded successfully")
except FileNotFoundError:
    print("WARNING: Model file not found. Train the model first.")
    model = None

def extract_features(audio_data, sr=22050, n_mfcc=40, max_len=300):
    """Extract MFCC features from audio data"""
    try:
        mfccs = librosa.feature.mfcc(y=audio_data, sr=sr, n_mfcc=n_mfcc)
        
        if mfccs.shape[1] < max_len:
            mfccs = np.pad(mfccs, ((0, 0), (0, max_len - mfccs.shape[1])), mode='constant')
        else:
            mfccs = mfccs[:, :max_len]
        
        return mfccs.flatten()
    except Exception as e:
        raise Exception(f"Feature extraction failed: {e}")

def predict_from_features(features) -> Dict:
    """Make prediction from extracted features"""
    if model is None:
        raise Exception("Model not loaded")
    
    features = features.reshape(1, -1)
    prediction = model.predict(features)[0]
    probabilities = model.predict_proba(features)[0]
    
    result = {
        "detected_issue": prediction.replace('_', ' ').title(),
        "confidence_scores": {
            label.replace('_', ' ').title(): float(prob * 100)
            for label, prob in zip(model.classes_, probabilities)
        }
    }
    return result

@app.post("/upload-audio")
async def upload_audio(file: UploadFile = File(...)):
    """Upload and analyze audio file (MP3/WAV)"""
    try:
        # Read file
        contents = await file.read()
        audio_data, sr = librosa.load(io.BytesIO(contents), sr=22050, duration=30)
        
        # Extract features and predict
        features = extract_features(audio_data, sr)
        result = predict_from_features(features)
        
        return {"status": "success", "result": result}
    
    except Exception as e:
        return {"status": "error", "message": str(e)}

@app.websocket("/live-audio")
async def live_audio_stream(websocket: WebSocket):
    """WebSocket endpoint for live audio streaming"""
    await websocket.accept()
    
    try:
        while True:
            # Receive audio chunk (expects raw PCM float32 array as JSON)
            data = await websocket.receive_text()
            audio_chunk = json.loads(data)
            
            # Convert to numpy array
            audio_array = np.array(audio_chunk, dtype=np.float32)
            
            # Extract features and predict
            features = extract_features(audio_array, sr=22050)
            result = predict_from_features(features)
            
            # Send prediction back
            await websocket.send_json({"status": "success", "result": result})
    
    except WebSocketDisconnect:
        print("Client disconnected")
    except Exception as e:
        await websocket.send_json({"status": "error", "message": str(e)})

@app.get("/")
async def root():
    """Health check endpoint"""
    return {
        "message": "Vehicle Complaint Detection API",
        "model_loaded": model is not None,
        "endpoints": {
            "upload": "/upload-audio (POST)",
            "live": "/live-audio (WebSocket)"
        }
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)