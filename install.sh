#!/bin/bash

# Constants
NAME='gate'
GITNAME='git-update'
INSTALL_PATH='/usr/bin/gateRp'
GATE_SERVICE_FILE="/etc/systemd/system/$NAME.service"
GIT_SERVICE_FILE="/etc/systemd/system/$GITNAME.service"

# Exit on errors
set -e

# Check root permissions
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# Uninstall previous version if exists
if [ -d "$INSTALL_PATH" ]; then
    echo "Uninstalling previous version..."
    systemctl stop "$NAME.service" "$GITNAME.service" || true
    systemctl disable "$NAME.service" "$GITNAME.service" || true
    rm -f "$GATE_SERVICE_FILE" "$GIT_SERVICE_FILE" || true
    rm -rf "$INSTALL_PATH" || true
fi

# Install required Python libraries
echo "Installing python libraries..."
apt update
apt install -y python3.9 python3-pip
python3 -m pip install evdev pyusb pyudev requests python-dotenv watchdog netifaces

# Copy project directory
echo "Copying project directory..."
mkdir -p "$INSTALL_PATH"
git config --global --add safe.directory "$INSTALL_PATH"
chmod +x "$SCRIPT_PATH/src/main.py" "$SCRIPT_PATH/run.sh" "$SCRIPT_PATH/update.sh"
cp -ra "$SCRIPT_PATH/." "$INSTALL_PATH"
mkdir -p "/var/log/$NAME/"
mv "/var/log/$NAME/$NAME.log" "/var/log/$NAME/$NAME.log.$(date +'%F_%T').backup" &> /dev/null || true
touch "/var/log/$NAME/$NAME.log"

# Set up systemd services
echo "Setting up systemd services..."
cat << __EOF > "$GATE_SERVICE_FILE"
[Unit]
Description=$NAME
After=multi-user.target

[Service]
Type=idle
User=root
Restart=always
RestartSec=2
ExecStart=bash $INSTALL_PATH/run.sh

[Install]
WantedBy=multi-user.target
__EOF

cat << __EOF > "$GIT_SERVICE_FILE"
[Unit]
Description=$GITNAME

[Service]
User=root
ExecStart=bash $INSTALL_PATH/update.sh

[Install]
WantedBy=default.target
__EOF

# Reload systemd and enable services
echo "Configuring and enabling services..."
systemctl daemon-reload
systemctl enable "$NAME.service" "$GITNAME.service"
systemctl start "$NAME.service" "$GITNAME.service"

echo "Installation and setup completed."
