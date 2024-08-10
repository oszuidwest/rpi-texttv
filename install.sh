#!/usr/bin/env bash

# Set-up the functions library
FUNCTIONS_LIB_PATH="/tmp/functions.sh"
FUNCTIONS_LIB_URL="https://raw.githubusercontent.com/oszuidwest/bash-functions/main/common-functions.sh"

# General Raspberry Pi configuration
CONFIG_FILE_PATHS=("/boot/firmware/config.txt" "/boot/config.txt")
FIRST_IP=$(hostname -I | awk '{print $1}')

# Remove old functions library and download the latest version
rm -f "$FUNCTIONS_LIB_PATH"
if ! curl -s -o "$FUNCTIONS_LIB_PATH" "$FUNCTIONS_LIB_URL"; then
  echo -e "*** Failed to download functions library. Please check your network connection! ***"
  exit 1
fi

# Source the functions file
# shellcheck source=/tmp/functions.sh
source "$FUNCTIONS_LIB_PATH"

# Set color variables
set_colors

# Check if running as root
check_user_privileges normal

# Check if this is Linux
is_this_linux
is_this_os_64bit

# Check if we are running on a Raspberry Pi 4 or newer
check_rpi_model 4

# Timezone configuration
set_timezone Europe/Amsterdam

# Start with a clean terminal
clear

# Banner
cat << "EOF"
 ______   _ ___ ______        _______ ____ _____   _______     __
|__  / | | |_ _|  _ \ \      / / ____/ ___|_   _| |_   _\ \   / /
  / /| | | || || | | \ \ /\ / /|  _| \___ \ | |     | |  \ \ / / 
 / /_| |_| || || |_| |\ V  V / | |___ ___) || |     | |   \ V /  
/____|\___/|___|____/  \_/\_/  |_____|____/ |_|     |_|    \_/   
EOF

# Greeting
echo -e "${GREEN}⎎ Raspberry Pi Tekst TV set-up${NC}\n\n"
ask_user "DO_UPDATES" "y" "Do you want to perform all OS updates? (y/n)" "y/n"

# Update OS
if [ "$DO_UPDATES" == "y" ]; then
  update_os silent
fi

# Variables
WALLPAPER_URL="https://raw.githubusercontent.com/oszuidwest/windows10-baseline/main/assets/ZWTV-wallpaper.png"
CHROME_URL="https://teksttv.zuidwesttv.nl/"

# Install dependencies
install_packages silent xserver-xorg x11-xserver-utils x11-utils xinit openbox unclutter chromium-browser feh ttf-mscorefonts-installer fonts-crosextra-carlito fonts-crosextra-caladea realvnc-vnc-server

########## REFACTOR ONDERSTAANDE ################
#
#
#
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
sleep 3

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
