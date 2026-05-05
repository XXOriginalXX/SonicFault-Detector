from fastapi import FastAPI, File, UploadFile, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
import numpy as np
import librosa
import joblib
import io
from typing import Dict
import json

app = FastAPI(title="Vehicle Complaint Detection API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

MODEL_PATH = r'C:\Users\adith\Desktop\Projects\Audacity\vehicle_complaint_model.pkl'

try:
    model = joblib.load(MODEL_PATH)
    print(f"Model loaded successfully | Classes: {model.classes_}")
except Exception as e:
    print(f"WARNING: Model loading failed: {e}")
    model = None


# ─────────────────────────────────────────────────────────────────
# DIY SOLUTIONS — one entry per trained class
# ─────────────────────────────────────────────────────────────────
DIY_SOLUTIONS = {
    "low_compression": {
        "severity": "high",
        "diy_possible": False,
        "steps": [
            "Check for blue or white smoke from the exhaust.",
            "Perform a compression test on each cylinder using a compression gauge.",
            "Check spark plugs for oil fouling or carbon buildup.",
            "Inspect the air filter for blockage.",
        ],
        "tools_needed": ["Compression Gauge", "Spark Plug Wrench", "Inspection Camera"],
        "estimated_time": "1–2 hours (diagnosis only)",
        "warning": "Low compression usually requires internal engine repair (rings, valves, head gasket). Take to a mechanic immediately."
    },

    "turbo_leak": {
        "severity": "high",
        "diy_possible": True,
        "steps": [
            "Wait for the engine to fully cool before inspection.",
            "Check all intercooler hoses for cracks or loose clamps.",
            "Inspect the turbo inlet and outlet pipes for oil residue.",
            "Tighten all air intake connections and hose clamps.",
            "Start the engine and listen for a hissing sound under boost.",
        ],
        "tools_needed": ["Hose Clamp Pliers", "Flathead Screwdriver", "Degreaser Spray", "Torch/Flashlight"],
        "estimated_time": "30–45 minutes",
        "warning": "Turbochargers run at extreme temperatures. Never inspect while the engine is hot."
    },

    "belt_issue": {
        "severity": "medium",
        "diy_possible": True,
        "steps": [
            "Turn off the engine and allow it to cool completely.",
            "Locate the serpentine/drive belt — check for cracks, fraying, or glazing.",
            "Check belt tension using a tension gauge or by pressing the belt midpoint.",
            "Inspect all belt-driven pulleys (alternator, AC compressor, power steering) for wobble.",
            "Replace the belt if worn; adjust tensioner if slack.",
        ],
        "tools_needed": ["Socket Set", "Belt Tension Gauge", "Replacement Serpentine Belt", "Breaker Bar"],
        "estimated_time": "30–60 minutes",
        "warning": "Never inspect or touch belts while the engine is running."
    },

    "timing_belt_issue": {
        "severity": "critical",
        "diy_possible": False,
        "steps": [
            "Listen for a high-pitched ticking or slapping noise from the top of the engine.",
            "Check if the timing belt inspection cover can be removed to visually inspect the belt.",
            "Look for visible cracks, fraying, or missing teeth on the belt.",
            "Check the timing belt tensioner for looseness.",
        ],
        "tools_needed": ["Inspection Mirror", "Torch/Flashlight", "Screwdriver"],
        "estimated_time": "30 minutes (inspection only)",
        "warning": "CRITICAL: A snapped timing belt causes catastrophic engine damage (bent valves, piston damage). Do NOT drive the vehicle — get it towed to a workshop immediately."
    },

    "lock_issue": {
        "severity": "low",
        "diy_possible": True,
        "steps": [
            "Spray graphite-based lubricant into the lock cylinder.",
            "Check the key for signs of wear or bending — try a spare key.",
            "Check the door lock actuator fuse in the fuse box.",
            "Test the central locking button from inside the vehicle.",
            "If electronic, check the door lock actuator connector for corrosion.",
        ],
        "tools_needed": ["Graphite Lubricant Spray", "Spare Key", "Fuse Tester", "Multimeter"],
        "estimated_time": "15–30 minutes",
        "warning": "Do NOT use WD-40 or oil-based lubricants in lock cylinders — they attract dust and worsen the problem over time."
    },

    "injector_issue": {
        "severity": "high",
        "diy_possible": False,
        "steps": [
            "Listen for a rhythmic ticking or knocking at idle — injector knock has a distinct metallic tap.",
            "Check for rough idling, misfires, or increased fuel consumption.",
            "Add a fuel injector cleaner to the tank as a first step.",
            "Connect an OBD-II scanner to check for misfire codes (P030X series).",
            "Do a fuel pressure test to check if the fuel pump is delivering correct pressure.",
        ],
        "tools_needed": ["OBD-II Scanner", "Fuel Pressure Gauge", "Injector Cleaner Additive"],
        "estimated_time": "30–45 minutes (diagnosis)",
        "warning": "Faulty injectors cause incomplete combustion and can damage the catalytic converter. Get a professional injector cleaning or replacement."
    },

    "oil_coolant_mixing": {
        "severity": "critical",
        "diy_possible": False,
        "steps": [
            "Check the engine oil dipstick — oil will look milky/frothy if coolant is mixing.",
            "Check the coolant reservoir for a brown oily film on the cap or inside the tank.",
            "Check the exhaust for white sweet-smelling smoke.",
            "Do NOT continue driving — this indicates a blown head gasket or cracked cylinder head.",
            "Get a cooling system pressure test done at a workshop.",
        ],
        "tools_needed": ["Dipstick Inspection", "Coolant Test Strips", "Combustion Leak Tester"],
        "estimated_time": "Immediate inspection — do not delay",
        "warning": "CRITICAL: Oil and coolant mixing destroys the engine rapidly. Stop driving the vehicle immediately and get it towed to a workshop."
    },

    "no_issue": {
        "severity": "none",
        "diy_possible": True,
        "steps": [
            "Check engine oil level on the dipstick — top up if low.",
            "Inspect coolant level in the reservoir.",
            "Check tyre pressures including the spare.",
            "Clean or replace the air filter if due.",
            "Check all exterior lights are functioning.",
        ],
        "tools_needed": ["Standard Tool Kit", "Tyre Pressure Gauge"],
        "estimated_time": "10–15 minutes",
        "warning": "Your vehicle sounds healthy! Stick to your scheduled maintenance intervals."
    },

    "general_issue": {
        "severity": "medium",
        "diy_possible": False,
        "steps": [
            "Connect an OBD-II scanner and note all active fault codes.",
            "Monitor the dashboard for any warning lights.",
            "Check engine oil, coolant, brake fluid, and power steering fluid levels.",
            "Listen carefully for the nature of the noise — knocking, hissing, grinding — and note when it occurs.",
        ],
        "tools_needed": ["OBD-II Scanner", "Standard Tool Kit"],
        "estimated_time": "N/A",
        "warning": "Unspecified complaint detected. Avoid long drives or high loads until properly diagnosed by a mechanic."
    },
}


# ─────────────────────────────────────────────────────────────────
# GRAPH DATA GENERATOR
# Produces two waveforms: "detected" (characteristic of the issue)
# and "normal" (clean healthy engine baseline).
# All values are deterministic per issue_key — always consistent.
# 200 points across a simulated 2-second window.
# ─────────────────────────────────────────────────────────────────

GRAPH_PROFILES = {
    # issue_key: (base_freq, spike_intensity, spike_interval, noise_level, waveform_type)
    # waveform_type: "sine" | "rough" | "missing" | "hiss" | "knock"
    "no_issue":          (45,  0.00, 0,  0.04, "sine"),
    "low_compression":   (40,  0.55, 18, 0.18, "missing"),   # periodic drop-outs
    "turbo_leak":        (50,  0.45, 12, 0.22, "hiss"),      # high freq hiss bursts
    "belt_issue":        (38,  0.50, 22, 0.15, "rough"),     # irregular amplitude
    "timing_belt_issue": (42,  0.70, 10, 0.20, "knock"),     # hard periodic knock
    "lock_issue":        (35,  0.30, 30, 0.10, "rough"),     # mild irregularity
    "injector_issue":    (44,  0.60, 14, 0.25, "knock"),     # sharp injector tap
    "oil_coolant_mixing":(40,  0.40, 20, 0.30, "rough"),     # noisy baseline
    "general_issue":     (42,  0.35, 16, 0.20, "rough"),
}

def generate_graph_data(issue_key: str, n_points: int = 200):
    """
    Returns two lists of {x, y} points:
      - detected_wave : characteristic waveform for the detected issue
      - normal_wave   : clean healthy engine baseline
    Both share the same x-axis (time in ms over 2 seconds).
    """
    profile = GRAPH_PROFILES.get(issue_key, GRAPH_PROFILES["general_issue"])
    base_freq, spike_intensity, spike_interval, noise_level, wtype = profile

    rng = np.random.default_rng(seed=abs(hash(issue_key)) % (2**31))
    t   = np.linspace(0, 2, n_points)          # 0–2 seconds
    x   = (t * 1000).tolist()                  # milliseconds for frontend

    # ── Normal baseline (always clean sine, same frequency) ──────
    normal_y = (
        0.6 * np.sin(2 * np.pi * 45 * t)
        + 0.03 * rng.standard_normal(n_points)
    )

    # ── Detected waveform ────────────────────────────────────────
    base = 0.6 * np.sin(2 * np.pi * base_freq * t)

    if wtype == "sine":
        # Healthy — slight noise only
        detected_y = base + noise_level * rng.standard_normal(n_points)

    elif wtype == "rough":
        # Amplitude modulation — belt slip / general roughness
        mod = 1 + 0.4 * np.sin(2 * np.pi * 3 * t)
        detected_y = base * mod + noise_level * rng.standard_normal(n_points)

    elif wtype == "missing":
        # Periodic cylinder drop-out (low compression)
        detected_y = base + noise_level * rng.standard_normal(n_points)
        for i in range(0, n_points, spike_interval):
            width = min(4, n_points - i)
            detected_y[i:i+width] *= 0.15   # amplitude collapses

    elif wtype == "hiss":
        # High-frequency burst (turbo leak)
        hiss = 0.35 * np.sin(2 * np.pi * 300 * t)
        burst = np.zeros(n_points)
        for i in range(0, n_points, spike_interval):
            width = min(6, n_points - i)
            burst[i:i+width] = 1.0
        detected_y = base + hiss * burst + noise_level * rng.standard_normal(n_points)

    elif wtype == "knock":
        # Sharp positive spikes (injector tap / timing knock)
        detected_y = base + noise_level * rng.standard_normal(n_points)
        for i in range(0, n_points, spike_interval):
            if i < n_points:
                detected_y[i] += spike_intensity * (1 + 0.3 * rng.standard_normal())

    else:
        detected_y = base + noise_level * rng.standard_normal(n_points)

    # Clip to [-1, 1] and round for clean JSON
    def to_points(y_arr):
        y_clipped = np.clip(y_arr, -1.0, 1.0)
        return [{"x": round(float(x[i]), 2), "y": round(float(y_clipped[i]), 4)}
                for i in range(n_points)]

    return {
        "detected_wave": to_points(detected_y),
        "normal_wave":   to_points(normal_y),
        "issue_key":     issue_key,
        "x_label":       "Time (ms)",
        "y_label":       "Amplitude",
        "duration_ms":   2000,
    }


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
        return {
            "detected_issue": "Model Not Loaded",
            "detected_issue_key": "unknown",
            "confidence": 0.0
        }

    features = features.reshape(1, -1)
    prediction  = model.predict(features)[0]
    proba       = model.predict_proba(features)[0]
    confidence  = float(np.max(proba))

    if confidence < 0.45:
        return {
            "detected_issue":     "Unrecognized Issue",
            "detected_issue_key": "general_issue",
            "confidence":         round(confidence, 3)
        }

    return {
        "detected_issue":     str(prediction).replace('_', ' ').title(),
        "detected_issue_key": str(prediction).lower(),
        "confidence":         round(confidence, 3)
    }


# ── Endpoints ────────────────────────────────────────────────────

@app.get("/")
async def root():
    classes = list(model.classes_) if model is not None else []
    return {
        "status":       "success",
        "message":      "Vehicle Complaint Detection API",
        "model_loaded": model is not None,
        "classes":      classes
    }

@app.websocket("/live-audio")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    print("WebSocket connection established")
    try:
        while True:
            data = await websocket.receive_text()
            # This line now works because json is imported
            audio_buffer = np.array(json.loads(data), dtype=np.float32)
            
            if len(audio_buffer) > 0:
                features = extract_features(audio_buffer, sr=22050)
                result = predict_from_features(features)
                graph_data = generate_graph_data(result["detected_issue_key"])
                
                await websocket.send_json({
                    "status": "success",
                    "result": result,
                    "graph": graph_data
                })
    except WebSocketDisconnect:
        print("WebSocket client disconnected")
    except Exception as e:
        print(f"WebSocket Error: {e}")
        await websocket.send_json({"status": "error", "message": str(e)})

@app.post("/upload-audio")
async def upload_audio(file: UploadFile = File(...)):
    try:
        contents        = await file.read()
        audio_data, sr  = librosa.load(io.BytesIO(contents), sr=22050, duration=10)
        features        = extract_features(audio_data, sr)
        result          = predict_from_features(features)
        graph_data      = generate_graph_data(result["detected_issue_key"])
        return {
            "status": "success",
            "result": result,
            "graph":  graph_data       # ← graph included directly in upload response
        }
    except Exception as e:
        return {"status": "error", "message": str(e)}


@app.get("/graph/{issue_key}")
async def get_graph(issue_key: str):
    """
    Returns waveform graph data for any issue key.
    Frontend can call this independently to render the chart.

    Response shape:
    {
      "status": "success",
      "graph": {
        "issue_key":     "turbo_leak",
        "x_label":       "Time (ms)",
        "y_label":       "Amplitude",
        "duration_ms":   2000,
        "detected_wave": [ { "x": 0.0, "y": 0.312 }, ... ],   // 200 points
        "normal_wave":   [ { "x": 0.0, "y": 0.298 }, ... ]    // 200 points
      }
    }
    """
    graph_data = generate_graph_data(issue_key.lower())
    return {"status": "success", "graph": graph_data}


@app.get("/diy-solution/{issue_key}")
async def get_diy(issue_key: str):
    solution = DIY_SOLUTIONS.get(issue_key.lower(), DIY_SOLUTIONS["general_issue"])
    return {
        "status": "success",
        "solution": {
            "issue": issue_key.replace('_', ' ').title(),
            **solution
        }
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)