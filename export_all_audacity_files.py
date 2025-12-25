import os
import sqlite3
import wave
import numpy as np

BASE_PATH = r"C:\Users\adith\Desktop\Projects\Audacity\Audacity\Audacity"

def extract_audio_from_aup3(aup3_file, output_wav):
    try:
        conn = sqlite3.connect(aup3_file)
        cursor = conn.cursor()
        
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
        tables = [t[0] for t in cursor.fetchall()]
        
        if 'sampleblocks' not in tables:
            print(f"  No sampleblocks table in {os.path.basename(aup3_file)}")
            conn.close()
            return False
        
        cursor.execute("SELECT samples, summin, summax, sumrms FROM sampleblocks ORDER BY blockid")
        blocks = cursor.fetchall()
        
        if not blocks:
            print(f"  No audio data in {os.path.basename(aup3_file)}")
            conn.close()
            return False
        
        audio_data = []
        
        for block in blocks:
            samples_blob = block[0]
            
            if samples_blob is None:
                continue
            
            if isinstance(samples_blob, (int, float)):
                continue
            
            num_samples = len(samples_blob) // 4
            samples = np.frombuffer(samples_blob, dtype=np.float32, count=num_samples)
            audio_data.extend(samples)
        
        if not audio_data:
            print(f"  No valid audio samples in {os.path.basename(aup3_file)}")
            conn.close()
            return False
        
        audio_array = np.array(audio_data, dtype=np.float32)
        
        audio_array = np.clip(audio_array, -1.0, 1.0)
        audio_int16 = np.int16(audio_array * 32767)
        
        sample_rate = 44100
        
        with wave.open(output_wav, 'w') as wav_file:
            wav_file.setnchannels(1)
            wav_file.setsampwidth(2)
            wav_file.setframerate(sample_rate)
            wav_file.writeframes(audio_int16.tobytes())
        
        conn.close()
        duration = len(audio_int16) / sample_rate
        print(f"  Converted: {os.path.basename(aup3_file)} ({duration:.1f}s)")
        return True
        
    except Exception as e:
        print(f"  Error: {os.path.basename(aup3_file)} - {e}")
        return False

def inspect_aup3_structure(aup3_file):
    try:
        conn = sqlite3.connect(aup3_file)
        cursor = conn.cursor()
        
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
        tables = cursor.fetchall()
        
        print(f"\nInspecting: {os.path.basename(aup3_file)}")
        print(f"Tables: {[t[0] for t in tables]}")
        
        if 'sampleblocks' in [t[0] for t in tables]:
            cursor.execute("PRAGMA table_info(sampleblocks)")
            columns = cursor.fetchall()
            print(f"Columns: {[c[1] for c in columns]}")
            
            cursor.execute("SELECT COUNT(*) FROM sampleblocks")
            count = cursor.fetchone()[0]
            print(f"Blocks: {count}")
            
            cursor.execute("SELECT * FROM sampleblocks LIMIT 1")
            sample = cursor.fetchone()
            if sample:
                print(f"Sample row: blockid={sample[0]}, has_data={sample[1] is not None}")
        
        conn.close()
        
    except Exception as e:
        print(f"Inspection error: {e}")

def convert_all_aup3_files():
    total_files = 0
    converted_files = 0
    
    print("="*60)
    print("CONVERTING .aup3 FILES TO .wav FORMAT")
    print("="*60)
    
    first_file = True
    
    for folder in os.listdir(BASE_PATH):
        folder_path = os.path.join(BASE_PATH, folder)
        if not os.path.isdir(folder_path):
            continue
        
        aup3_files = [f for f in os.listdir(folder_path) if f.endswith('.aup3')]
        
        if not aup3_files:
            continue
        
        if first_file:
            first_aup3 = os.path.join(folder_path, aup3_files[0])
            inspect_aup3_structure(first_aup3)
            first_file = False
            print("\n" + "="*60)
        
        print(f"\nProcessing: {folder}")
        
        for file in aup3_files:
            total_files += 1
            aup3_path = os.path.join(folder_path, file)
            wav_path = aup3_path.replace('.aup3', '.wav')
            
            if os.path.exists(wav_path):
                print(f"  Skipped: {os.path.basename(wav_path)} (exists)")
                converted_files += 1
                continue
            
            if extract_audio_from_aup3(aup3_path, wav_path):
                converted_files += 1
    
    print("\n" + "="*60)
    print(f"RESULT: {converted_files}/{total_files} files converted")
    print("="*60)
    
    if converted_files == 0:
        print("\nThese .aup3 files may be incompatible or corrupted.")
        print("Please ask your friend for the original .wav or .mp3 files.")
    else:
        print("\nNow run: python train_model.py")

if __name__ == "__main__":
    convert_all_aup3_files()