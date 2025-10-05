# Raspberry Pi Text TV Setup

This repository provides a script to configure a Raspberry Pi as a narrowcasting screen, displaying a webpage in full-screen mode using Chromium. Additionally it can optionally use VLC to play a background audio track. The setup process includes installing essential packages, configuring the window manager, setting a fallback wallpaper, and enabling VNC for remote access.

## Compatibility

### Supported Models
- **Raspberry Pi 3B/3B+** - Single HDMI output
- **Raspberry Pi 4** - Dual HDMI output support
- **Raspberry Pi 5** - Dual HDMI output support
- **Raspberry Pi 400** - Dual HDMI output support (keyboard computer)
- **Raspberry Pi 500** - Dual HDMI output support (keyboard computer)

This setup is tested with Raspberry Pi OS Bookworm (64-bit) Lite. There's no need to install a full desktop environment, as this script installs and configures a lightweight alternative.

### Dual Screen Support
Raspberry Pi 4, Pi 5, Pi 400, and Pi 500 models support dual HDMI outputs. The script automatically detects these models and offers to configure both displays for simultaneous content display.

### Cooling Fan Support (Pi 5 Only)
For Raspberry Pi 5 models, the script automatically configures the active cooling fan with the following settings:
- **Activation temperature**: 55°C - The fan starts when the CPU reaches this temperature
- **Deactivation temperature**: 35°C - The fan stops when the CPU cools down to this point
- **Hysteresis**: 20°C - This prevents the fan from constantly switching on/off around the threshold
- **Speed**: 100% (255/255) - The fan runs at maximum speed when active

This configuration ensures efficient cooling while minimizing unnecessary fan activation during light workloads.

#### Audio on Dual Screens
When dual screen mode is enabled with VLC audio, the script automatically configures audio output to both HDMI ports. This ensures that the same audio stream plays through both connected displays. The implementation uses two synchronized VLC instances, each targeting a specific HDMI audio device (vc4hdmi0 and vc4hdmi1).

## Usage
To get started, install Raspberry Pi OS Bookworm (64-bit) and log in as a non-privileged user. It's important to avoid using `su` or `sudo` for root access during this process. Run the following command to execute the setup script:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/oszuidwest/rpi-texttv/main/install.sh)"
```

This command will download and run the script, automatically installing the necessary packages and configuring your Raspberry Pi for kiosk mode.

## Customization

The prompts for various configuration options. Below is a table listing each option, its default value, and a brief explanation:

| Option         | Default Value | Description |
|----------------|---------------|-------------|
| `DO_UPDATES`   | `y`           | Perform all available OS updates during setup. Set to 'n' to skip updates. |
| `INSTALL_VNC`  | `y`           | Install RealVNC for remote desktop access. Set to 'n' to skip. |
| `INSTALL_VLC`  | `y`           | Install VLC for audio playback. When dual screen is enabled, audio will play on both HDMI outputs. Set to 'n' to skip. |
| `VLC_URL`      | `https://icecast.zuidwest.cloud/zuidwest.stl` | The stream URL for VLC playback. Only prompted if `INSTALL_VLC` is set to 'y'. |
| `CHROME_URL`   | `https://teksttv.zuidwesttv.nl/` | The URL to display in Chromium kiosk mode. |
| `USE_DUAL_SCREEN` | `n`        | Configure dual HDMI outputs (Pi 4/5/400/500 only). Set to 'y' to enable second display. |
| `CHROME_URL_2` | Same as `CHROME_URL` | The URL to display on the second screen. Only prompted if `USE_DUAL_SCREEN` is set to 'y'. |

## Video and Boot Options

The setup script applies specific video and boot options to ensure compatibility with various displays and force a consistent resolution. These are configured using the `VIDEO_OPTIONS` and `BOOT_OPTIONS` variables:

| Option          | Default Value                       | Description |
|-----------------|-----------------------------------|-------------|
| `VIDEO_OPTIONS` | `video=HDMI-A-1:1920x1080@50D`     | Forces HDMI output at 1080i resolution with a 50Hz refresh rate. For dual screen setup, automatically adds `video=HDMI-A-2:1920x1080@50D`. The `D` signifies interlaced mode. |
| `BOOT_OPTIONS`  | `drm.edid_firmware=edid/edid.bin vc4.force_hotplug=0x01 consoleblank=1 logo.nologo` | Configures custom EDID data, forces HDMI hotplug detection (0x03 for dual screens), disables console blanking, and suppresses the boot logo. |

To adjust these settings, edit the `VIDEO_OPTIONS` and `BOOT_OPTIONS` variables in the script.

## Architectural Overview
- **X11**: The display server that provides the graphical environment necessary for running applications like Chromium on the Raspberry Pi. The script ensures X11 starts automatically on boot.
- **Unclutter**: A utility to hide the mouse cursor when idle, for a clean screen presentation.
- **Openbox**: A lightweight window manager that automatically starts and manages Chromium and other display settings, ensuring a minimal graphical environment.
- **Feh**: Used to display a fallback wallpaper in the absence of other graphical content.
- **Chromium**: Runs in kiosk mode to display web applications full-screen. For dual screen setups, two independent Chromium instances are launched with separate user data directories.
- **RealVNC**: Provides remote desktop access to the Raspberry Pi on the default port 5900.

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing
Contributions are welcome! Feel free to submit issues and pull requests for improvements and additional features.
