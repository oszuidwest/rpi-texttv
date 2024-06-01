#!/bin/bash

# Variables
WALLPAPER_URL="https://raw.githubusercontent.com/oszuidwest/windows10-baseline/main/assets/ZWTV-wallpaper.png"
CHROME_URL="https://teksttv.zuidwesttv.nl/"

# Update package list
sudo apt update

# Install Necessary Packages
PACKAGES=(
    xserver-xorg
    x11-xserver-utils
    xinit
    openbox
    unclutter
    chromium-browser
    feh
    ttf-mscorefonts-installer
    fonts-crosextra-carlito
    fonts-crosextra-caladea
    realvnc-vnc-server
)

for PACKAGE in "${PACKAGES[@]}"; do
    echo "Installing $PACKAGE..."
    if ! sudo apt install --no-install-recommends -y "$PACKAGE"; then
        echo "Error installing $PACKAGE"
        exit 1
    fi
done

# Setup Fallback Wallpaper
sudo mkdir -p /var/fallback
sudo wget "$WALLPAPER_URL" -O /var/fallback/fallback.png

# Configure Openbox
mkdir -p ~/.config/openbox
cat << EOF > ~/.config/openbox/autostart
#!/bin/bash
xset -dpms          # Disable DPMS (Energy Star) features.
xset s off          # Disable screen saver.
xset s noblank      # Don't blank the video device.

# Hide the mouse cursor when idle
unclutter -idle 0 &

# Display the fallback image as a background using feh
feh --fullscreen /var/fallback/fallback.png &

# Wait for feh to start
sleep 5

# Start Chromium in kiosk mode
chromium-browser --kiosk --noerrdialogs --disable-infobars --disable-session-crashed-bubble \
    --disable-features=TranslateUI --app=$CHROME_URL --incognito \
    --disable-extensions --disable-background-networking --disable-background-timer-throttling \
    --disable-client-side-phishing-detection --disable-default-apps --disable-hang-monitor \
    --disable-popup-blocking --disable-prompt-on-repost --disable-sync --metrics-recording-only \
    --no-first-run --no-default-browser-check --disable-component-update \
    --disable-backgrounding-occluded-windows --disable-renderer-backgrounding
EOF

chmod +x ~/.config/openbox/autostart

# Enable X11 and VNC on Boot
cat << 'EOF' >> ~/.profile
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    startx
fi
EOF

# Configure Automatic Login and VNC
sudo raspi-config nonint do_boot_behaviour B2
sudo raspi-config nonint do_vnc 0

# Clean Up
sudo apt autoremove -y

# Reboot System
echo "Configuration complete. The system will now reboot."
sudo reboot
