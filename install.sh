#!/usr/bin/env bash

# External resources
FALLBACKIMG_URL="https://raw.githubusercontent.com/oszuidwest/windows10-baseline/main/assets/ZWTV-wallpaper.png"
FUNCTIONS_LIB_URL="https://raw.githubusercontent.com/oszuidwest/bash-functions/main/common-functions.sh"
EDID_DATA_URL="https://raw.githubusercontent.com/oszuidwest/rpi-texttv/main/edid.bin"

# System paths
FUNCTIONS_LIB_PATH="/tmp/functions.sh"
CMDLINE_FILE="/boot/firmware/cmdline.txt"
CONFIG_FILE="/boot/firmware/config.txt"

# Display configuration (1920x1080 @ 50Hz interlaced)
VIDEO_OPTIONS="video=HDMI-A-1:1920x1080@50D"
BOOT_OPTIONS="drm.edid_firmware=edid/edid.bin vc4.force_hotplug=0x01 consoleblank=1 logo.nologo"

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

# Check required tools are available
require_tool "curl" "sed"

# Check if the script is running as root
check_user_privileges regular

# Ensure the script is running on a supported platform (Linux, 64-bit, Raspberry Pi 3 or newer)
is_this_linux
is_this_os_64bit
check_rpi_model 3

# Clear the terminal
clear

# Display Banner
cat << "EOF"
 ______   _ ___ ______        _______ ____ _____   _______     __
|__  / | | |_ _|  _ \ \      / / ____/ ___|_   _| |_   _\ \   / /
  / /| | | || || | | \ \ /\ / /|  _| \___ \ | |     | |  \ \ / / 
 / /_| |_| || || |_| |\ V  V / | |___ ___) || |     | |   \ V /  
/____|\___/|___|____/  \_/\_/  |_____|____/ |_|     |_|    \_/   
EOF

echo -e "${GREEN}⎎ Raspberry Pi Tekst TV Set-up${NC}\n\n"
# Gather user preferences
ask_user "DO_UPDATES" "y" "Do you want to perform all OS updates? (y/n)" "y/n"
ask_user "INSTALL_VNC" "y" "Do you want to install VNC for remote control of this device? (y/n)" "y/n"
ask_user "INSTALL_VLC" "y" "Do you want to install VLC player to play a stream behind the narrowcast? (y/n)" "y/n"

if [ "$INSTALL_VLC" == "y" ]; then
  ask_user "VLC_URL" "https://icecast.zuidwest.cloud/zuidwest.stl" "Enter the URL of the stream that VLC should play" "str"
fi

ask_user "CHROME_URL" "https://teksttv.zuidwesttv.nl/" "What URL should be opened and displayed by Chrome?" "str"

# Check for dual HDMI capability (Pi 4/5/400/500)
PI_MODEL=$(tr -d '\0' < /proc/device-tree/model 2>/dev/null || echo "")

if [[ "$PI_MODEL" =~ Pi\ [45] ]] || [[ "$PI_MODEL" =~ Pi\ [45]00 ]]; then
  ask_user "USE_DUAL_SCREEN" "n" "This Pi supports dual screens. Configure second HDMI output? (y/n)" "y/n"
  
  if [ "$USE_DUAL_SCREEN" == "y" ]; then
    ask_user "CHROME_URL_2" "$CHROME_URL" "URL for second screen (default: same as primary)?" "str"
    VIDEO_OPTIONS="$VIDEO_OPTIONS video=HDMI-A-2:1920x1080@50D"
    BOOT_OPTIONS="${BOOT_OPTIONS/vc4.force_hotplug=0x01/vc4.force_hotplug=0x03}"
  fi
fi

# Set system timezone
set_timezone Europe/Amsterdam

# Apply cmdline.txt modifications
echo -e "${BLUE}►► Applying video and boot options...${NC}"

# Backup cmdline.txt before modifications
if ! backup_file "$CMDLINE_FILE"; then
  exit 1
fi

# Clean up any existing boot settings to prevent duplicates
sudo sed -i 's/ vc4\.force_hotplug=[^ ]*//g' "$CMDLINE_FILE"
sudo sed -i 's/ video=HDMI-A-[12]:[^ ]*//g' "$CMDLINE_FILE"
sudo sed -i 's/ drm\.edid_firmware=[^ ]*//g' "$CMDLINE_FILE"
sudo sed -i 's/ consoleblank=[^ ]*//g' "$CMDLINE_FILE"
sudo sed -i 's/ logo\.nologo//g' "$CMDLINE_FILE"

# Apply new boot options
CMDLINE_OPTIONS="$VIDEO_OPTIONS $BOOT_OPTIONS"
sudo sed -i "\$ s|\$| $CMDLINE_OPTIONS|" "$CMDLINE_FILE"

# Apply cooling fan configuration for Pi 5 only
if [[ "$PI_MODEL" =~ Pi\ 5 ]]; then
  echo -e "${BLUE}►► Configuring cooling fan settings for Pi 5...${NC}"

  # Backup config.txt before modifications
  if ! backup_file "$CONFIG_FILE"; then
    exit 1
  fi

  # Remove any existing cooler section to prevent duplicates
  sudo sh -c "awk '/^\[cooler\]/{skip=1; next} /^\[/{skip=0} !skip' '$CONFIG_FILE' > '$CONFIG_FILE.tmp' && \
    mv '$CONFIG_FILE.tmp' '$CONFIG_FILE'" 2>/dev/null || true

  # Add cooling fan configuration
  echo -e "\n[cooler]" | sudo tee -a "$CONFIG_FILE" > /dev/null
  echo "dtparam=cooling_fan=on" | sudo tee -a "$CONFIG_FILE" > /dev/null
  echo "dtparam=fan_temp0=55000" | sudo tee -a "$CONFIG_FILE" > /dev/null
  echo "dtparam=fan_temp0_hyst=20000" | sudo tee -a "$CONFIG_FILE" > /dev/null
  echo "dtparam=fan_temp0_speed=255" | sudo tee -a "$CONFIG_FILE" > /dev/null
fi

# Perform OS updates if requested by the user
if [ "$DO_UPDATES" == "y" ]; then
  update_os silent
fi

# Install necessary packages
install_packages silent xserver-xorg x11-xserver-utils x11-utils xinit openbox unclutter-xfixes \
  chromium-browser feh ttf-mscorefonts-installer fonts-crosextra-carlito \
  fonts-crosextra-caladea \
  "$( [ "$INSTALL_VLC" == "y" ] && echo "vlc" )" \
  "$( [ "$INSTALL_VNC" == "y" ] && echo "realvnc-vnc-server" )"

# Set up the fallback wallpaper
sudo mkdir -p /var/fallback
download_file "$FALLBACKIMG_URL" "/var/fallback/fallback.png" "fallback wallpaper"

# Download EDID data
sudo mkdir -p /lib/firmware/edid/
download_file "$EDID_DATA_URL" "/lib/firmware/edid/edid.bin" "EDID configuration"

# Configure Openbox
echo -e "${BLUE}►► Configuring Openbox...${NC}"
mkdir -p ~/.config/openbox

# Save configuration
cat << EOF > ~/.config/openbox/display.conf
USE_DUAL_SCREEN="${USE_DUAL_SCREEN:-n}"
CHROME_URL="${CHROME_URL}"
CHROME_URL_2="${CHROME_URL_2:-$CHROME_URL}"
INSTALL_VLC="${INSTALL_VLC:-n}"
VLC_URL="${VLC_URL:-}"
EOF

cat << 'EOF' > ~/.config/openbox/autostart
#!/bin/bash

# Load configuration
[ -f "${HOME}/.config/openbox/display.conf" ] && . "${HOME}/.config/openbox/display.conf"

# Disable screen blanking
xset -dpms
xset s off
xset s noblank

# Configure primary display (1920x1080 @ 50Hz interlaced)
xrandr --newmode "1920x1080_50i" 74.25 1920 2448 2492 2640 1080 1084 1094 1125 interlace -hsync +vsync
xrandr --addmode HDMI-1 "1920x1080_50i"
xrandr --output HDMI-1 --mode "1920x1080_50i"

# Configure second display if enabled
if [ "$USE_DUAL_SCREEN" = "y" ]; then
  xrandr --addmode HDMI-2 "1920x1080_50i" 2>/dev/null
  xrandr --output HDMI-2 --mode "1920x1080_50i" --right-of HDMI-1 2>/dev/null
fi

# Set wallpaper and hide cursor
feh --bg-fill /var/fallback/fallback.png &
unclutter --timeout 0 --hide-on-touch --start-hidden --fork

# Chromium kiosk mode flags
CHROME_FLAGS="--kiosk --noerrdialogs --disable-infobars --disable-session-crashed-bubble \
  --disable-features=Translate --incognito --disable-extensions --disable-background-networking \
  --disable-background-timer-throttling --disable-client-side-phishing-detection --disable-default-apps \
  --disable-hang-monitor --disable-popup-blocking --disable-prompt-on-repost --disable-sync \
  --metrics-recording-only --no-first-run --no-default-browser-check --disable-component-update \
  --disable-backgrounding-occluded-windows --disable-renderer-backgrounding"

# Start Chromium instances
chromium-browser $CHROME_FLAGS --window-position=0,0 --user-data-dir=/tmp/chrome-1 --app="$CHROME_URL" &

if [ "$USE_DUAL_SCREEN" = "y" ]; then
  sleep 2
  chromium-browser $CHROME_FLAGS --window-position=1920,0 --user-data-dir=/tmp/chrome-2 --app="${CHROME_URL_2:-$CHROME_URL}" &
fi

# Start VLC audio stream if configured
if [ "${INSTALL_VLC:-n}" = "y" ] && [ -n "$VLC_URL" ]; then
  # Start VLC for HDMI Port 0 (primary display)
  cvlc --aout alsa --alsa-audio-device=hdmi:CARD=vc4hdmi0,DEV=0 --gain 0.15 --intf dummy --loop \
    "$VLC_URL" :http-user-agent="Raspberry Pi ($(hostname)) - HDMI0" &
  
  # Start VLC for HDMI Port 1 if dual screen is enabled
  if [ "$USE_DUAL_SCREEN" = "y" ]; then
    sleep 1  # Small delay to prevent simultaneous startup issues
    cvlc --aout alsa --alsa-audio-device=hdmi:CARD=vc4hdmi1,DEV=0 --gain 0.15 --intf dummy --loop \
      "$VLC_URL" :http-user-agent="Raspberry Pi ($(hostname)) - HDMI1" &
  fi
fi
EOF

# Make the autostart script executable
chmod +x ~/.config/openbox/autostart

# Configure X11 to start on boot
echo -e "${BLUE}►► Configuring auto-start...${NC}"
cat << 'EOF' >> ~/.profile
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
  startx
fi
EOF

# Configure boot behavior
sudo raspi-config nonint do_boot_behaviour B2

if [ "$INSTALL_VNC" == "y" ]; then
  sudo raspi-config nonint do_vnc 0
fi

# Clean up unnecessary packages
echo -e "${BLUE}►► Cleaning up...${NC}"
sudo apt -qq remove cups -y
sudo apt -qq autoremove -y

# Configuration complete
echo -e "${GREEN}Configuration complete. The system will now reboot.${NC}\n"
sudo reboot
