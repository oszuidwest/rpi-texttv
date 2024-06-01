#!/bin/bash

# Update systeem
sudo apt update
sudo apt upgrade -y

# Installeer benodigde pakketten
sudo apt install --no-install-recommends xserver-xorg x11-xserver-utils xinit openbox unclutter -y # X Server
sudo apt install chromium-browser -y # Browser
sudo apt install ttf-mscorefonts-installer fonts-crosextra-carlito fonts-crosextra-caladea # Fonts

# Openbox configureren
mkdir -p ~/.config/openbox
cat <<EOL > ~/.config/openbox/autostart
#!/bin/bash
xset -dpms            # Disable DPMS (Energy Star) features.
xset s off            # Disable screen saver.
xset s noblank        # Don't blank the video device.

# Start Chromium in kiosk mode
chromium-browser --kiosk --noerrdialogs --disable-infobars --disable-session-crashed-bubble --disable-features=TranslateUI --app=https://teksttv.zuidwesttv.nl/ --incognito --disable-extensions --disable-background-networking --disable-background-timer-throttling --disable-client-side-phishing-detection --disable-default-apps --disable-hang-monitor --disable-popup-blocking --disable-prompt-on-repost --disable-sync --metrics-recording-only --no-first-run --no-default-browser-check --disable-component-update --disable-backgrounding-occluded-windows --disable-renderer-backgrounding --disable-background-timer-throttling
EOL

chmod +x ~/.config/openbox/autostart

# Automatisch X11 en VNC starten bij opstarten
cat <<EOL >> ~/.profile
if [ -z "\$DISPLAY" ] && [ "\$(tty)" = "/dev/tty1" ]; then
    startx
fi
EOL

# Configureer automatische aanmelding
sudo raspi-config nonint do_boot_behaviour B2

# VNC configureren via raspi-config (headless)
sudo raspi-config nonint do_vnc 0

# Opruimen
sudo apt autoremove -y

# Reboot om wijzigingen toe te passen
echo "Configuratie voltooid. Het systeem zal nu opnieuw opstarten."
sudo reboot