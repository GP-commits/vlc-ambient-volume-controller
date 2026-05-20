# VLC Ambient Volume Controller (VLC Plugin)

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform-VLC](https://img.shields.io/badge/Platform-VLC-orange.svg)](https://www.videolan.org/vlc/)

A hybrid VLC Media Player extension that automatically adjusts audio playback volume based on the ambient noise in your environment. If the room gets noisy, the extension boosts VLC's volume; as it quiets down, it smoothly scales it back.

---

## Architecture

VLC's Lua scripting engine is sandboxed and lacks native bindings to access microphone hardware directly. To solve this, this project utilizes a **hybrid design**:

1. **Python Audio Analyzer (`vlc_noise_listener.py`)**: A lightweight script running in the background. It captures microphone levels using the `sounddevice` library, applies an exponential smoothing filter to raw Root Mean Square (RMS) measurements, and writes the calculated target volume to a shared JSON state file.
2. **VLC Lua Extension (`ambient_volume.lua`)**: A native Lua plugin placed in VLC's local extensions folder. When activated, VLC executes its periodic `loop()` callback (every ~100-300ms) to read the target volume from the shared state file and set VLC's playback volume via `vlc.volume.set()`.
3. **Batch Installer (`setup_vlc.bat`)**: Automates installation of Python dependencies and deploys the Lua script directly to VLC's roaming extensions folder on Windows.

---

## Installation & Setup

1. Clone or download this repository.
2. Double-click the **`setup_vlc.bat`** file. This will automatically:
   - Check and verify your Python installation.
   - Install required Python dependencies (`sounddevice` and `numpy`) via pip.
   - Locate and copy `ambient_volume.lua` to VLC's roaming extensions folder (`%APPDATA%\vlc\lua\extensions`).
3. Run the Python background microphone analyzer by double-clicking **`vlc_noise_listener.py`** (leave the command prompt open).
4. Open **VLC Media Player**.
5. In the top menu, navigate to **View** -> **Ambient Volume Controller**.
6. Play your media! The volume slider in VLC will adjust automatically as you make noise.

---

## Configuration

After running the Python script for the first time, a `config.json` file is created in the directory. You can edit this file to customize behavior:

```json
{
  "enabled": true,
  "baseVolume": 30,       
  "maxVolume": 90,        
  "sensitivity": 50,      
  "noiseThreshold": 10,   
  "smoothing": 0.15       
}
```

- **`baseVolume`**: The default volume percentage (0-100%) when the room is quiet.
- **`maxVolume`**: The maximum volume percentage (0-100%) VLC should scale up to.
- **`sensitivity`**: Response rate multiplier (1-100). Higher sensitivity makes volume increase much quicker.
- **`noiseThreshold`**: Ambient decibel/noise level floor to ignore (0-50).
- **`smoothing`**: Exponential moving average coefficient (0.01 - 1). Lower numbers mean smoother transitions, while higher numbers mean faster but more erratic volume adjustments.

---

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
