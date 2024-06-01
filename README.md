# Raspberry Pi Kiosk Setup

This repository contains a script to set up a Raspberry Pi as a kiosk, displaying a web page in full-screen mode using Chromium. The setup includes installing necessary packages, configuring Openbox, setting a fallback wallpaper, and enabling VNC.

## Script Overview

The `setup.sh` script performs the following tasks:

1. Updates the package list.
2. Installs necessary packages for the kiosk setup.
3. Sets up a fallback wallpaper.
4. Configures Openbox to disable power management, hide the mouse cursor, and start Chromium in kiosk mode displaying the specified web page.
5. Enables X11 and VNC on boot.
6. Configures automatic login and VNC.
7. Cleans up unnecessary packages.
8. Reboots the system to apply changes.

## Usage

1. **Clone the Repository**

   ```bash
   git clone https://github.com/yourusername/raspberry-pi-kiosk-setup.git
   cd raspberry-pi-kiosk-setup
   ```

2. **Modify Variables**

   If needed, modify the `WALLPAPER_URL` and `CHROME_URL` variables in the `setup.sh` script to your preferred wallpaper and web page URL.

3. **Run the Script**

   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```

   This will execute the script, install necessary packages, and configure the Raspberry Pi for kiosk mode.

## Customization

You can customize the script to use a different wallpaper or web page by modifying the `WALLPAPER_URL` and `CHROME_URL` variables at the beginning of the `setup.sh` script.

```bash
WALLPAPER_URL="your_custom_wallpaper_url"
CHROME_URL="your_custom_chrome_url"
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

Feel free to submit issues and pull requests for improvements and additional features.
