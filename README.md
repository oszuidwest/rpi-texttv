# Raspberry Pi Text TV Setup

This script configures a Raspberry Pi as a narrowcasting screen, displaying a webpage in full-screen Chromium with optional background audio via mpv.

## Compatibility

### Supported Models
- **Raspberry Pi 4**
- **Raspberry Pi 5**
- **Raspberry Pi 400**
- **Raspberry Pi 500**

Requires Raspberry Pi OS Trixie (64-bit) Lite. No full desktop environment needed — the script installs a lightweight X11 stack.

### Dual Screen Support
All supported models have dual HDMI outputs. The script offers to configure both displays for simultaneous content display.

### Cooling Fan (Pi 5 Only)
The script automatically configures the active cooling fan: on at 55°C, off at 35°C, 100% speed.

## Usage
Install Raspberry Pi OS Trixie (64-bit) Lite and log in as a non-privileged user. Do not use `su` or `sudo`. Run:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/oszuidwest/rpi-texttv/main/install.sh)"
```

## Configuration Options

The script prompts for the following options during setup:

| Option           | Default                                              | Description                                                    |
|------------------|------------------------------------------------------|----------------------------------------------------------------|
| `DO_UPDATES`     | `y`                                                  | Perform OS updates during setup                                |
| `INSTALL_VNC`    | `y`                                                  | Install RealVNC for remote desktop access (port 5900)          |
| `INSTALL_MPV`    | `y`                                                  | Install mpv for background audio playback                      |
| `MPV_URL`        | `https://icecast.zuidwest.cloud/zuidwest.stl`        | Audio stream URL for mpv                                       |
| `MPV_VOLUME`     | `75`                                                 | Audio volume (0-100)                                           |
| `CHROME_URL`     | `https://teksttv.zuidwest.cloud/zuidwest-1/`         | URL to display in Chromium kiosk mode                          |
| `USE_DUAL_SCREEN`| `n`                                                  | Configure second HDMI output                                   |
| `CHROME_URL_2`   | Same as `CHROME_URL`                                 | URL for second screen                                          |

## Video and Boot Options

The script configures HDMI output at 1080i/50Hz with custom EDID data. These can be adjusted by editing the `VIDEO_OPTIONS` and `BOOT_OPTIONS` variables in the script:

| Variable         | Default                                                                              |
|------------------|--------------------------------------------------------------------------------------|
| `VIDEO_OPTIONS`  | `video=HDMI-A-1:1920x1080@50D`                                                      |
| `BOOT_OPTIONS`   | `drm.edid_firmware=edid/edid.bin vc4.force_hotplug=0x01 consoleblank=1 logo.nologo`  |

For dual screen setups, `video=HDMI-A-2:1920x1080@50D` is added automatically and `vc4.force_hotplug` is set to `0x03`.

## Architecture

The display stack: **X11 → Openbox → Chromium** (kiosk mode), with **feh** for wallpaper, **unclutter** to hide the cursor, and optionally **RealVNC** for remote access and **mpv** for audio. Dual screen runs two independent Chromium instances with separate user data directories.

## License
MIT License. See [LICENSE](LICENSE).

## Contributing
Contributions welcome. Feel free to submit issues and pull requests.
