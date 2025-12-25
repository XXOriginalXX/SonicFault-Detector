import requests
import json
import asyncio
import websockets
import pyaudio
import numpy as np

# ==================== FILE UPLOAD EXAMPLE ====================
def upload_audio_file(file_path):
    """Upload an audio file for analysis"""
    url = "http://localhost:8000/upload-audio"
    
    with open(file_path, 'rb') as f:
        files = {'file': f}
        response = requests.post(url, files=files)
    
    result = response.json()
    print(json.dumps(result, indent=2))
    return result

# ==================== LIVE AUDIO EXAMPLE ====================
async def live_audio_recording():
    """Record and stream live audio to the server"""
    uri = "ws://localhost:8000/live-audio"
    
    # Audio settings
    CHUNK = 22050 * 2  # 2 seconds of audio at 22050 Hz
    FORMAT = pyaudio.paFloat32
    CHANNELS = 1
    RATE = 22050
    
    p = pyaudio.PyAudio()
    stream = p.open(format=FORMAT, channels=CHANNELS, rate=RATE,
                    input=True, frames_per_buffer=CHUNK)
    
    print("Recording... Press Ctrl+C to stop")
    
    async with websockets.connect(uri) as websocket:
        try:
            while True:
                # Record audio chunk
                data = stream.read(CHUNK, exception_on_overflow=False)
                audio_array = np.frombuffer(data, dtype=np.float32)
                
                # Send to server
                await websocket.send(json.dumps(audio_array.tolist()))
                
                # Receive prediction
                response = await websocket.recv()
                result = json.loads(response)
                
                if result['status'] == 'success':
                    issue = result['result']['detected_issue']
                    print(f"\nDetected: {issue}")
                    for label, score in result['result']['confidence_scores'].items():
                        print(f"  {label}: {score:.2f}%")
                else:
                    print(f"Error: {result['message']}")
        
        except KeyboardInterrupt:
            print("\nStopping recording...")
        finally:
            stream.stop_stream()
            stream.close()
            p.terminate()

# ==================== USAGE ====================
if __name__ == "__main__":
    # Example 1: Upload file
    print("=== FILE UPLOAD TEST ===")
    #upload_audio_file("test_audio.wav")
    
    # Example 2: Live recording (requires pyaudio)
    # Uncomment to test live audio:
    # print("\n=== LIVE RECORDING TEST ===")
    asyncio.run(live_audio_recording())