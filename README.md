# Raspberry Pi Kiosk Setup

This repository contains a script to set up a Raspberry Pi as a kiosk, displaying a web page in full-screen mode using Chromium. The setup includes installing necessary packages, configuring Openbox, setting a fallback wallpaper, and enabling VNC.

## Script Overview

The `install.sh` script performs the following tasks:

1. Updates the package list.
2. Installs necessary packages for the kiosk setup.
3. Sets up a fallback wallpaper.
4. Configures Openbox to disable power management, hide the mouse cursor, and start Chromium in kiosk mode displaying the specified web page.
5. Enables X11 and VNC on boot.
6. Configures automatic login and VNC.
7. Cleans up unnecessary packages.
8. Reboots the system to apply changes.

## Usage

First, install Raspberry Pi OS Bookworm (64-bit) and log in as a non-privileged user. Do not switch to or use `su`/`sudo` for root access. Run the following command:

   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/oszuidwest/rpi-teksttv/main/install.sh)".
   ```

   This will execute the script, install necessary packages, and configure the Raspberry Pi for kiosk mode.

## Customization

You can customize the script to use a different wallpaper or web page by modifying the `WALLPAPER_URL` and `CHROME_URL` variables at the beginning of the `install.sh` script.

```bash
WALLPAPER_URL="your_custom_wallpaper_url"
CHROME_URL="your_custom_chrome_url"
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

Feel free to submit issues and pull requests for improvements and additional features.
