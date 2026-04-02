from fastapi import FastAPI, File, UploadFile, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
import numpy as np
import librosa
import joblib
import io
import json
from typing import Dict

app = FastAPI(title="Vehicle Complaint Detection API")

# Allow Frontend (localhost:5173) to communicate with Backend
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
except Exception as e:
    print(f"WARNING: Model loading failed: {e}")
    model = None

def extract_features(audio_data, sr=22050, n_mfcc=40, max_len=300):
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
    if model is None:
        return {"detected_issue": "Model Not Loaded", "detected_issue_key": "unknown"}
    
    features = features.reshape(1, -1)
    prediction = model.predict(features)[0]
    
    return {
        "detected_issue": str(prediction).replace('_', ' ').title(),
        "detected_issue_key": str(prediction).lower()
    }

@app.get("/")
async def root():
    return {
        "status": "success",
        "message": "Vehicle Complaint Detection API",
        "model_loaded": model is not None
    }

@app.post("/upload-audio")
async def upload_audio(file: UploadFile = File(...)):
    try:
        contents = await file.read()
        audio_data, sr = librosa.load(io.BytesIO(contents), sr=22050, duration=10)
        features = extract_features(audio_data, sr)
        result = predict_from_features(features)
        return {"status": "success", "result": result}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@app.websocket("/live-audio")
async def live_audio_stream(websocket: WebSocket):
    await websocket.accept()
    try:
        while True:
            data = await websocket.receive_text()
            audio_chunk = json.loads(data)
            audio_array = np.array(audio_chunk, dtype=np.float32)
            features = extract_features(audio_array, sr=22050)
            result = predict_from_features(features)
            await websocket.send_json({"status": "success", "result": result})
    except WebSocketDisconnect:
        print("Client disconnected")
    except Exception as e:
        await websocket.send_json({"status": "error", "message": str(e)})

@app.get("/diy-solution/{issue_key}")
async def get_diy(issue_key: str):
    # This provides the data your Frontend 'diy' stage expects
    return {
        "status": "success",
        "solution": {
            "issue": issue_key.replace('_', ' ').title(),
            "severity": "medium",
            "diy_possible": True,
            "steps": ["Locate the affected component.", "Clean surrounding area.", "Tighten loose bolts or replace filter.", "Restart engine to verify."],
            "tools_needed": ["Wrench", "Screwdriver Set", "Microfiber Cloth"],
            "estimated_time": "20-40 mins",
            "warning": "Ensure the vehicle is parked on level ground and the engine is cool."
        }
    }

@app.get("/roadside-assistance")
async def get_roadside(country: str = "India", brand: str = None):
    return {
        "status": "success",
        "country": country,
        "national_helplines": [
            {"name": "Emergency Services", "number": "112"},
            {"name": "Highway Helpline", "number": "1033"}
        ],
        "brand_assistance": {
            "number": "1800-102-1800" if brand == "Maruti Suzuki" else "1800-419-8888",
            "availability": "24/7"
        }
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)