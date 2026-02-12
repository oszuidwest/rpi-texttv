#!/usr/bin/env bash

# External resources
FALLBACKIMG_URL="https://raw.githubusercontent.com/oszuidwest/windows10-baseline/main/assets/ZWTV-wallpaper.png"
FUNCTIONS_LIB_URL="https://raw.githubusercontent.com/oszuidwest/bash-functions/main/common-functions.sh"
EDID_DATA_URL="https://raw.githubusercontent.com/oszuidwest/rpi-texttv/main/edid.bin"

# System paths
FUNCTIONS_LIB_PATH=$(mktemp)
CMDLINE_FILE="/boot/firmware/cmdline.txt"
CONFIG_FILE="/boot/firmware/config.txt"

# Clean up temporary file on exit
trap 'rm -f "$FUNCTIONS_LIB_PATH"' EXIT

# Display configuration (1920x1080 @ 50Hz interlaced)
VIDEO_OPTIONS="video=HDMI-A-1:1920x1080@50D"
BOOT_OPTIONS="drm.edid_firmware=edid/edid.bin vc4.force_hotplug=0x01 consoleblank=1 logo.nologo"

# Download the functions library
if ! curl -s -o "$FUNCTIONS_LIB_PATH" "$FUNCTIONS_LIB_URL"; then
  echo -e "*** Failed to download functions library. Please check your network connection! ***"
  exit 1
fi

# shellcheck source=/dev/null
source "$FUNCTIONS_LIB_PATH"
# Set color variables
set_colors
# Check required tools are available
require_tool "curl" "sed"

# Validate environment (must run as regular user, on Linux 64-bit, Pi 3 or newer)
check_user_privileges regular
is_this_linux
is_this_os_64bit
check_rpi_model 3

clear
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
ask_user "INSTALL_MPV" "y" "Do you want to install mpv player to play a stream behind the narrowcast? (y/n)" "y/n"

if [[ "$INSTALL_MPV" == "y" ]]; then
  ask_user "MPV_URL" "https://icecast.zuidwest.cloud/zuidwest.stl" "Enter the URL of the stream that mpv should play" "str"
  ask_user "MPV_VOLUME" "75" "Enter the volume for mpv (0-100)" "str"
fi

ask_user "CHROME_URL" "https://teksttv.zuidwesttv.nl/" "What URL should be opened and displayed by Chrome?" "str"

# Detect Pi model for dual HDMI support (Pi 4/5/400/500)
PI_MODEL=$(tr -d '\0' < /proc/device-tree/model 2>/dev/null || echo "")

if [[ "$PI_MODEL" =~ Pi\ [45] ]] || [[ "$PI_MODEL" =~ Pi\ [45]00 ]]; then
  ask_user "USE_DUAL_SCREEN" "n" "This Pi supports dual screens. Configure second HDMI output? (y/n)" "y/n"

  if [[ "$USE_DUAL_SCREEN" == "y" ]]; then
    ask_user "CHROME_URL_2" "$CHROME_URL" "URL for second screen (default: same as primary)?" "str"
    VIDEO_OPTIONS="$VIDEO_OPTIONS video=HDMI-A-2:1920x1080@50D"
    BOOT_OPTIONS="${BOOT_OPTIONS/vc4.force_hotplug=0x01/vc4.force_hotplug=0x03}"
  fi
fi

set_timezone Europe/Amsterdam

echo -e "${BLUE}►► Applying video and boot options...${NC}"
if ! backup_file "$CMDLINE_FILE"; then
  exit 1
fi

# Remove existing boot parameters to prevent duplicates
sudo sed -i 's/ vc4\.force_hotplug=[^ ]*//g' "$CMDLINE_FILE"
sudo sed -i 's/ video=HDMI-A-[12]:[^ ]*//g' "$CMDLINE_FILE"
sudo sed -i 's/ drm\.edid_firmware=[^ ]*//g' "$CMDLINE_FILE"
sudo sed -i 's/ consoleblank=[^ ]*//g' "$CMDLINE_FILE"
sudo sed -i 's/ logo\.nologo//g' "$CMDLINE_FILE"

CMDLINE_OPTIONS="$VIDEO_OPTIONS $BOOT_OPTIONS"
sudo sed -i "\$ s|\$| $CMDLINE_OPTIONS|" "$CMDLINE_FILE"

# Pi 5: Configure active cooling fan (55°C on, 35°C off, 100% speed)
if [[ "$PI_MODEL" =~ Pi\ 5 ]]; then
  echo -e "${BLUE}►► Configuring cooling fan settings for Pi 5...${NC}"
  if ! backup_file "$CONFIG_FILE"; then
    exit 1
  fi

  # Remove existing [cooler] section to prevent duplicates
  sudo sh -c "awk '/^\[cooler\]/{skip=1; next} /^\[/{skip=0} !skip' '$CONFIG_FILE' > '$CONFIG_FILE.tmp' && \
    mv '$CONFIG_FILE.tmp' '$CONFIG_FILE'" 2>/dev/null || true


  echo -e "\n[cooler]" | sudo tee -a "$CONFIG_FILE" > /dev/null
  echo "dtparam=cooling_fan=on" | sudo tee -a "$CONFIG_FILE" > /dev/null
  echo "dtparam=fan_temp0=55000" | sudo tee -a "$CONFIG_FILE" > /dev/null
  echo "dtparam=fan_temp0_hyst=20000" | sudo tee -a "$CONFIG_FILE" > /dev/null
  echo "dtparam=fan_temp0_speed=255" | sudo tee -a "$CONFIG_FILE" > /dev/null
fi

# Perform OS updates if requested by the user
if [[ "$DO_UPDATES" == "y" ]]; then
  update_os silent
fi

# Install necessary packages
install_packages silent xserver-xorg x11-xserver-utils x11-utils xinit openbox unclutter-xfixes \
  chromium-browser feh ttf-mscorefonts-installer fonts-crosextra-carlito \
  fonts-crosextra-caladea \
  "$([[ "$INSTALL_MPV" == "y" ]] && echo "mpv")" \
  "$([[ "$INSTALL_VNC" == "y" ]] && echo "realvnc-vnc-server")"

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
INSTALL_MPV="${INSTALL_MPV:-n}"
MPV_URL="${MPV_URL:-}"
MPV_VOLUME="${MPV_VOLUME:-75}"
EOF

cat << 'EOF' > ~/.config/openbox/autostart
#!/usr/bin/env bash
[ -f "${HOME}/.config/openbox/display.conf" ] && . "${HOME}/.config/openbox/display.conf"

# Disable screen blanking
xset -dpms
xset s off
xset s noblank

# Configure displays (1920x1080 @ 50Hz interlaced)
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

# Start Chromium in kiosk mode
CHROME_FLAGS="--kiosk --noerrdialogs --disable-infobars --disable-session-crashed-bubble \
  --disable-features=Translate --disable-translate --incognito --disable-extensions --disable-background-networking \
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
EOF

chmod +x ~/.config/openbox/autostart

# Create mpv systemd services for auto-restart on crash
if [[ "$INSTALL_MPV" == "y" ]]; then
  echo -e "${BLUE}►► Configuring mpv systemd services...${NC}"
  mkdir -p ~/.config/systemd/user

  create_mpv_service() {
    cat > ~/.config/systemd/user/mpv-hdmi"$1".service <<EOF
[Unit]
Description=MPV Audio Stream (HDMI$1)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/mpv --audio-device=alsa/hdmi:CARD=vc4hdmi$1,DEV=0 --volume=${MPV_VOLUME:-75} --network-timeout=2 --demuxer-readahead-secs=1 --user-agent="Raspberry Pi ($(hostname)) - HDMI$1" "${MPV_URL}"
Restart=always
RestartSec=5
StartLimitIntervalSec=0

[Install]
WantedBy=default.target
EOF
    systemctl --user enable mpv-hdmi"$1".service
  }

  create_mpv_service 0
  [[ "$USE_DUAL_SCREEN" == "y" ]] && create_mpv_service 1

  sudo loginctl enable-linger "$USER"
  systemctl --user daemon-reload
fi

# Start X11 automatically on tty1 login
echo -e "${BLUE}►► Configuring auto-start...${NC}"
cat << 'EOF' >> ~/.profile
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
  startx
fi
EOF

# Configure boot behavior
sudo raspi-config nonint do_boot_behaviour B2

if [[ "$INSTALL_VNC" == "y" ]]; then
  sudo raspi-config nonint do_vnc 0
fi

# Clean up unnecessary packages
echo -e "${BLUE}►► Cleaning up...${NC}"
sudo apt -qq remove cups -y
sudo apt -qq autoremove -y

# Configuration complete
echo -e "${GREEN}Configuration complete. The system will now reboot.${NC}\n"
sudo reboot
