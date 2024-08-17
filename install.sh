#!/usr/bin/env bash

# Variables (Update these if needed)
WALLPAPER_URL="https://raw.githubusercontent.com/oszuidwest/windows10-baseline/main/assets/ZWTV-wallpaper.png"
CHROME_URL="https://teksttv.zuidwesttv.nl/"
FUNCTIONS_LIB_URL="https://raw.githubusercontent.com/oszuidwest/bash-functions/main/common-functions.sh"

# Constants
FUNCTIONS_LIB_PATH="/tmp/functions.sh"
CMDLINE_FILE="/boot/firmware/cmdline.txt"
VIDEO_OPTION="video=HDMI-A-1:1920x1080@50D video=HDMI-A-1:D"

# Remove old functions library and download the latest version
rm -f "$FUNCTIONS_LIB_PATH"
if ! curl -s -o "$FUNCTIONS_LIB_PATH" "$FUNCTIONS_LIB_URL"; then
  echo -e "*** Failed to download functions library. Please check your network connection! ***"
  exit 1
fi

# Source the functions file
# shellcheck source=/dev/null
source "$FUNCTIONS_LIB_PATH"

# Set color variables
set_colors

# Check if the script is running as root
check_user_privileges normal

# Ensure the script is running on a supported platform (Linux, 64-bit, Raspberry Pi 3 or newer)
is_this_linux
is_this_os_64bit
check_rpi_model 3

# Clear the terminal for a clean start
clear

# Display Banner
cat << "EOF"
 ______   _ ___ ______        _______ ____ _____   _______     __
|__  / | | |_ _|  _ \ \      / / ____/ ___|_   _| |_   _\ \   / /
  / /| | | || || | | \ \ /\ / /|  _| \___ \ | |     | |  \ \ / / 
 / /_| |_| || || |_| |\ V  V / | |___ ___) || |     | |   \ V /  
/____|\___/|___|____/  \_/\_/  |_____|____/ |_|     |_|    \_/   
EOF

# Greet the user
echo -e "${GREEN}⎎ Raspberry Pi Tekst TV Set-up${NC}\n\n"
ask_user "DO_UPDATES" "y" "Do you want to perform all OS updates? (y/n)" "y/n"

# Set the system timezone
set_timezone Europe/Amsterdam

# Configure video resolution if not already set
echo -e "${BLUE}►► Setting video resolution...${NC}"
if ! grep -q "$VIDEO_OPTION" "$CMDLINE_FILE"; then
  echo "No resolution force option found in $CMDLINE_FILE, appending..."
  sudo sed -i "$ s/$/ $VIDEO_OPTION/" "$CMDLINE_FILE"
  echo "Resolution set to $VIDEO_OPTION"
else
  echo "Resolution $VIDEO_OPTION already exists in $CMDLINE_FILE, no changes made."
fi

# Perform OS updates if requested by the user
if [ "$DO_UPDATES" == "y" ]; then
  update_os silent
fi

# Install necessary packages
install_packages silent xserver-xorg x11-xserver-utils x11-utils xinit openbox unclutter-xfixes chromium-browser feh ttf-mscorefonts-installer fonts-crosextra-carlito fonts-crosextra-caladea realvnc-vnc-server

# Set up the fallback wallpaper
sudo mkdir -p /var/fallback
sudo wget -q "$WALLPAPER_URL" -O /var/fallback/fallback.png

# Configure Openbox
echo -e "${BLUE}►► Configuring Openbox...${NC}"
mkdir -p ~/.config/openbox
cat << EOF > ~/.config/openbox/autostart
#!/bin/bash
xset -dpms          # Disable DPMS (Energy Star) features.
xset s off          # Disable screen saver.
xset s noblank      # Don't blank the video device.

# Set the resolution
xrandr --newmode "1920x1080_50i"  74.25  1920 2448 2492 2640  1080 1084 1094 1125 interlace -hsync +vsync
xrandr --addmode HDMI-1 "1920x1080_50i"

# Set the resolution
xrandr --output HDMI-1 --mode "1920x1080_50i"

# Hide the mouse cursor when idle
unclutter --timeout 0 --hide-on-touch --start-hidden --fork

# Display the fallback image as a background using feh
feh --bg-fill /var/fallback/fallback.png &

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

# Configure X11 and VNC to start on boot
echo -e "${BLUE}►► Enabling X11 and VNC on boot...${NC}"
cat << 'EOF' >> ~/.profile
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
  startx
fi
EOF

sudo raspi-config nonint do_boot_behaviour B2
sudo raspi-config nonint do_vnc 0

# Clean up unnecessary packages
echo -e "${BLUE}►► Cleaning up unnecessary packages...${NC}"
sudo apt autoremove -y

# Reboot the system
echo -e "${GREEN}Configuration complete. The system will now reboot.${NC}\n\n"
sudo reboot
