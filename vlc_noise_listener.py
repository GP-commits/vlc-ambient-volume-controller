import time
import os
import sys
import json

# Try importing sounddevice and numpy, print helpful instructions if missing
try:
    import sounddevice as sd
    import numpy as np
except ImportError:
    print("Required Python libraries 'sounddevice' or 'numpy' are missing.", file=sys.stderr)
    print("Please run 'pip install sounddevice numpy' first.", file=sys.stderr)
    sys.exit(1)

# File Paths
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG_PATH = os.path.join(SCRIPT_DIR, "config.json")
SHARED_PATH = os.path.join(SCRIPT_DIR, "vlc_volume_state.json")

# Default Settings (VLC-specific)
settings = {
    "enabled": True,
    "baseVolume": 30,        # Volume percentage (0-100%) when quiet
    "maxVolume": 90,         # Maximum volume percentage (0-100%)
    "sensitivity": 50,       # Noise response sensitivity (1-100)
    "noiseThreshold": 10,    # Noise floor threshold (0-50)
    "smoothing": 0.15        # Exponential smoothing factor
}

last_config_mtime = 0
smoothed_noise = 0.0

def save_settings():
    try:
        with open(CONFIG_PATH, 'w') as f:
            json.dump(settings, f, indent=2)
    except Exception as e:
        print(f"Error saving config file: {e}", file=sys.stderr)

def load_settings():
    global last_config_mtime, settings
    try:
        if os.path.exists(CONFIG_PATH):
            mtime = os.path.getmtime(CONFIG_PATH)
            if mtime > last_config_mtime:
                last_config_mtime = mtime
                with open(CONFIG_PATH, 'r') as f:
                    data = json.load(f)
                    settings.update(data)
        else:
            save_settings()
    except Exception as e:
        # Ignore read errors if file is temporarily locked during write
        pass

def write_shared_state(raw_noise, smooth_noise, target_pct, vlc_volume):
    try:
        state = {
            "noise": int(raw_noise),
            "smoothedNoise": int(smooth_noise),
            "targetVolumePercentage": int(target_pct),
            "vlcVolume": int(vlc_volume),
            "active": settings["enabled"],
            "timestamp": time.time()
        }
        # Write to temporary file first and rename to make it atomic
        temp_path = SHARED_PATH + ".tmp"
        with open(temp_path, 'w') as f:
            json.dump(state, f)
        
        # Replace the active shared state file atomically
        if os.path.exists(SHARED_PATH):
            os.remove(SHARED_PATH)
        os.rename(temp_path, SHARED_PATH)
    except Exception as e:
        # Ignore write/lock conflicts with VLC reading the file
        pass

def audio_callback(indata, frames, time_info, status):
    global smoothed_noise
    
    # Calculate Root Mean Square (RMS)
    rms = np.sqrt(np.mean(indata**2))
    
    # Scale RMS value to 0-100 range.
    # Ambient room noise usually falls within 0.001 to 0.1 RMS.
    # We multiply by 450 to maps typical speaking/ambient noise to the 5-60 range.
    raw_noise = min(100.0, rms * 450.0)
    
    # Load any updated settings dynamically from config.json
    load_settings()
    
    if not settings["enabled"]:
        # When disabled, output static base volume
        vlc_vol = int(settings["baseVolume"] * 2.56)  # VLC volume is 0-256 (where 256 = 100%)
        write_shared_state(0, 0, settings["baseVolume"], vlc_vol)
        return

    # Apply exponential smoothing filter
    alpha = settings["smoothing"]
    smoothed_noise = (alpha * raw_noise) + ((1.0 - alpha) * smoothed_noise)
    
    base = settings["baseVolume"]
    max_v = settings["maxVolume"]
    threshold = settings["noiseThreshold"]
    sens = settings["sensitivity"]
    
    target_pct = base
    if smoothed_noise > threshold:
        excess = smoothed_noise - threshold
        
        # Sensitivity: 50 defaults to a 1.5x scale multiplier.
        # Higher sensitivity causes volume to react quicker.
        multiplier = (sens / 50.0) * 1.5
        target_pct = base + (excess * multiplier)
        if target_pct > max_v:
            target_pct = max_v
            
    target_pct = round(target_pct)
    vlc_volume = int(target_pct * 2.56) # 0..256 corresponds to 0..100% volume
    
    write_shared_state(raw_noise, smoothed_noise, target_pct, vlc_volume)

def main():
    print("=" * 60)
    print(" VLC Ambient Volume Controller Listener (Python)")
    print("=" * 60)
    print(f"Config File:   {CONFIG_PATH}")
    print(f"Shared State:  {SHARED_PATH}")
    print("\nListening to environment noise... Press Ctrl+C to stop.")
    
    # Initialize files
    load_settings()
    
    # Setup sounddevice InputStream
    try:
        with sd.InputStream(
            callback=audio_callback,
            channels=1,
            samplerate=16000,
            blocksize=1600
        ):
            while True:
                time.sleep(0.5)
    except KeyboardInterrupt:
        print("\nStopping background listener...")
    except Exception as e:
        print(f"\nStream Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
