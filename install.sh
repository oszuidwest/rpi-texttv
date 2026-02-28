#!/usr/bin/env bash

# External resources
FALLBACKIMG_URL="https://raw.githubusercontent.com/oszuidwest/windows10-baseline/main/assets/ZWTV-wallpaper.png"
FUNCTIONS_LIB_URL="https://raw.githubusercontent.com/oszuidwest/bash-functions/v2/common-functions.sh"
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
# Set color variables and get sudo command
set_colors
SUDO=$(get_sudo)
# Check required tools are available
assert_tool "curl" "sed"

# Validate environment (must run as regular user, on Linux 64-bit, Pi 4 or newer)
assert_user_privileged "regular"
assert_os_linux
assert_os_64bit
assert_hw_rpi 4

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
prompt_user "DO_UPDATES" "y" "Perform OS updates? (y/n)" "y/n"
prompt_user "INSTALL_VNC" "y" "Install VNC for remote control? (y/n)" "y/n"
prompt_user "INSTALL_MPV" "y" "Install mpv for audio stream behind narrowcast? (y/n)" "y/n"

if [[ "$INSTALL_MPV" == "y" ]]; then
  prompt_user "MPV_URL" "https://icecast.zuidwest.cloud/zuidwest.stl" "Audio stream URL for mpv" "str"
  prompt_user "MPV_VOLUME" "75" "MPV volume (0-100)" "num"
  if [[ "$MPV_VOLUME" -lt 0 || "$MPV_VOLUME" -gt 100 ]]; then
    echo -e "${RED}Volume must be between 0 and 100${NC}"
    exit 1
  fi
fi

prompt_user "CHROME_URL" "https://teksttv.zuidwest.cloud/zuidwest-1/" "URL to display in Chrome kiosk" "str"

# All supported models (Pi 4/5/400/500) have dual HDMI
prompt_user "USE_DUAL_SCREEN" "n" "Configure second HDMI output? (y/n)" "y/n"

if [[ "$USE_DUAL_SCREEN" == "y" ]]; then
  prompt_user "CHROME_URL_2" "$CHROME_URL" "URL for second screen" "str"
  VIDEO_OPTIONS="$VIDEO_OPTIONS video=HDMI-A-2:1920x1080@50D"
  BOOT_OPTIONS="${BOOT_OPTIONS/vc4.force_hotplug=0x01/vc4.force_hotplug=0x03}"
fi

PI_MODEL=$(tr -d '\0' < /proc/device-tree/model 2>/dev/null || echo "")

set_timezone Europe/Amsterdam

echo -e "${BLUE}►► Applying video and boot options...${NC}"
if ! file_backup "$CMDLINE_FILE"; then
  exit 1
fi

# Remove existing boot parameters to prevent duplicates
$SUDO sed -i \
  -e 's/ vc4\.force_hotplug=[^ ]*//g' \
  -e 's/ video=HDMI-A-[12]:[^ ]*//g' \
  -e 's/ drm\.edid_firmware=[^ ]*//g' \
  -e 's/ consoleblank=[^ ]*//g' \
  -e 's/ logo\.nologo//g' \
  "$CMDLINE_FILE"

CMDLINE_OPTIONS="$VIDEO_OPTIONS $BOOT_OPTIONS"
$SUDO sed -i "\$ s|\$| $CMDLINE_OPTIONS|" "$CMDLINE_FILE"

# Pi 5: Configure active cooling fan (55°C on, 35°C off, 100% speed)
if [[ "$PI_MODEL" =~ Pi\ 5 ]]; then
  echo -e "${BLUE}►► Configuring cooling fan settings for Pi 5...${NC}"
  if ! file_backup "$CONFIG_FILE"; then
    exit 1
  fi

  # Remove existing [cooler] section to prevent duplicates
  $SUDO sh -c "awk '/^\[cooler\]/{skip=1; next} /^\[/{skip=0} !skip' '$CONFIG_FILE' > '$CONFIG_FILE.tmp' && \
    mv '$CONFIG_FILE.tmp' '$CONFIG_FILE'" 2>/dev/null || true

  cat << 'COOLEREOF' | $SUDO tee -a "$CONFIG_FILE" > /dev/null

[cooler]
dtparam=cooling_fan=on
dtparam=fan_temp0=55000
dtparam=fan_temp0_hyst=20000
dtparam=fan_temp0_speed=255
COOLEREOF
fi

# Perform OS updates if requested by the user
if [[ "$DO_UPDATES" == "y" ]]; then
  apt_update --silent
fi

# Install necessary packages
apt_install --silent xserver-xorg x11-xserver-utils x11-utils xinit openbox unclutter-xfixes \
  chromium feh ttf-mscorefonts-installer fonts-crosextra-carlito \
  fonts-crosextra-caladea \
  "$([[ "$INSTALL_MPV" == "y" ]] && echo "mpv")" \
  "$([[ "$INSTALL_VNC" == "y" ]] && echo "realvnc-vnc-server")"

# Set up the fallback wallpaper
$SUDO mkdir -p /var/fallback
file_download "$FALLBACKIMG_URL" "/var/fallback/fallback.png" "fallback wallpaper"

# Download EDID data
$SUDO mkdir -p /usr/lib/firmware/edid/
file_download "$EDID_DATA_URL" "/usr/lib/firmware/edid/edid.bin" "EDID configuration"

# Configure Xorg to use the vc4 GPU (Pi 4/5 have v3d on card0 which confuses Xorg)
$SUDO mkdir -p /usr/share/X11/xorg.conf.d
cat << 'XORGEOF' | $SUDO tee /usr/share/X11/xorg.conf.d/99-vc4.conf > /dev/null
Section "Device"
  Identifier "vc4"
  Driver     "modesetting"
  Option     "kmsdev" "/dev/dri/card1"
EndSection
XORGEOF

# Disable Chromium translate prompt via managed policy
$SUDO mkdir -p /etc/chromium/policies/managed
echo '{"TranslateEnabled": false}' | $SUDO tee /etc/chromium/policies/managed/no-translate.json > /dev/null

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
  --incognito --disable-extensions --disable-background-networking \
  --disable-background-timer-throttling --disable-client-side-phishing-detection --disable-default-apps \
  --disable-hang-monitor --disable-popup-blocking --disable-prompt-on-repost --disable-sync \
  --metrics-recording-only --no-first-run --no-default-browser-check --disable-component-update \
  --disable-backgrounding-occluded-windows --disable-renderer-backgrounding --password-store=basic"

# Start Chromium instances
chromium $CHROME_FLAGS --window-position=0,0 --user-data-dir=/tmp/chrome-1 --app="$CHROME_URL" &

if [ "$USE_DUAL_SCREEN" = "y" ]; then
  sleep 2
  chromium $CHROME_FLAGS --window-position=1920,0 --user-data-dir=/tmp/chrome-2 --app="${CHROME_URL_2:-$CHROME_URL}" &
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

  $SUDO loginctl enable-linger "$USER"
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
$SUDO raspi-config nonint do_boot_behaviour B2

if [[ "$INSTALL_VNC" == "y" ]]; then
  $SUDO raspi-config nonint do_vnc 0
  # Prevent wayvnc from conflicting with RealVNC on port 5900
  $SUDO systemctl disable wayvnc.service 2>/dev/null || true
  $SUDO systemctl stop wayvnc.service 2>/dev/null || true
fi

# Clean up unnecessary packages
echo -e "${BLUE}►► Cleaning up...${NC}"
$SUDO apt -qq remove cups -y
$SUDO apt -qq autoremove -y

# Configuration complete
echo -e "${GREEN}Configuration complete. The system will now reboot.${NC}\n"
$SUDO reboot
