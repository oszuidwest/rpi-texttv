# Raspberry Pi Text TV Setup

This repository provides a script to configure a Raspberry Pi as a narrowcasting screen, displaying a webpage in full-screen mode using Chromium. The setup process includes installing essential packages, configuring the window manager, setting a fallback wallpaper, and enabling VNC for remote access.

## Compatibilty 
This setup is designed for Raspberry Pi 4 or newer models and is compatible only with Raspberry Pi OS Bookworm (64-bit) Lite. There's no need to install a full desktop environment, as this script installs and configures a lightweight alternative.

## Usage
To get started, install Raspberry Pi OS Bookworm (64-bit) and log in as a non-privileged user. It's important to avoid using `su` or `sudo` for root access during this process. Run the following command to execute the setup script:

   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/oszuidwest/rpi-texttv/main/install.sh)".
   ```

This command will download and run the script, automatically installing the necessary packages and configuring your Raspberry Pi for kiosk mode.

## Customization

You can easily customize the script to use a different wallpaper or webpage by editing the `WALLPAPER_URL` and `CHROME_URL` variables at the beginning of the install.sh script:

```bash
WALLPAPER_URL="your_custom_wallpaper_url"
CHROME_URL="your_custom_chrome_url"
```

## Architectural Overview

- **X11**: The display server that provides the graphical environment necessary for running applications like Chromium on the Raspberry Pi. The script ensures X11 starts automatically on boot.
- **Unclutter**: A utility to hide the mouse cursor when idle, for a clean screen presentation.
- **Openbox**: A lightweight window manager that automatically starts and manages Chromium and other display settings, ensuring a minimal graphical environment.
- **Feh**: Used to display a fallback wallpaper in the absence of other graphical content.
- **Chromium**: Used to display the web application in full-screen kiosk mode, concealing all browser controls and unnecessary features such as translations.
- **RealVNC**: Provides remote desktop access to the Raspberry Pi on the default port 5900.

### Foreced resolution
To ensure the Raspberry Pi displays the content correctly on different screens, the script includes settings to force a specific screen resolution. This is particularly useful when connecting to displays that may not automatically configure to the desired resolution.

By default, the script configures the Raspberry Pi to use a standard HD resolution (1920x1080) at 60Hz. If you need a diffrent resolution, you can change the `VIDEO_OPTION` variable and the `xrandr` commands. By default only the main screen (HDMI-A) is used.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Feel free to submit issues and pull requests for improvements and additional features.
