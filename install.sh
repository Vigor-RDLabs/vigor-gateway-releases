#!/bin/bash
set -e

echo "=== Installing Vigor Edge Gateway Daemon ==="

if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run install.sh as root (sudo ./install.sh)"
  exit 1
fi

# 1. Create dedicated unprivileged user
if ! id -u vigor >/dev/null 2>&1; then
    useradd -r -s /bin/false vigor
    echo "Created unprivileged service user 'vigor'"
fi

# 2. Setup directories
mkdir -p /opt/vigor/bin
mkdir -p /etc/vigor
mkdir -p /var/log/vigor

# 3. Install binary
cp bin/gateway /opt/vigor/bin/gateway
chmod 755 /opt/vigor/bin/gateway
chown -R vigor:vigor /opt/vigor

# 4. Install config template if config does not exist
if [ ! -f /etc/vigor/config.json ]; then
    cp config.json.template /etc/vigor/config.json
    echo "Installed default config to /etc/vigor/config.json"
fi

# 5. Restrict config file permissions (mode 0640, root:vigor)
chown root:vigor /etc/vigor/config.json
chmod 0640 /etc/vigor/config.json
echo "Protected /etc/vigor/config.json with mode 0640 (root:vigor)"

# 6. Install systemd service
cp vigor-gateway.service /etc/systemd/system/vigor-gateway.service
systemctl daemon-reload
systemctl enable vigor-gateway.service

echo "=== Vigor Edge Gateway Daemon Installed Successfully ==="
echo "Next steps:"
echo "1. Edit /etc/vigor/config.json with your Gateway ID, Token, and local RTSP cameras"
echo "2. Start service: sudo systemctl start vigor-gateway"
echo "3. Check logs: sudo journalctl -u vigor-gateway -f"
