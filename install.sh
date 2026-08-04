#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNTIME_PACKAGES=(ffmpeg openssl ca-certificates)

fail() {
  echo "Error: $*" >&2
  exit 1
}

require_root() {
  if [ "$EUID" -ne 0 ]; then
    fail "Please run install.sh as root (sudo ./install.sh)"
  fi
}

verify_bundle_files() {
  local required_files=(
    "$SCRIPT_DIR/bin/gateway"
    "$SCRIPT_DIR/config.json.template"
    "$SCRIPT_DIR/vigor-gateway.service"
  )
  local path
  for path in "${required_files[@]}"; do
    [ -f "$path" ] || fail "Release bundle is incomplete. Missing: $path"
  done
}

install_runtime_dependencies() {
  if ! command -v apt-get >/dev/null 2>&1; then
    fail "Unsupported Linux distribution. Install FFmpeg, OpenSSL, and CA certificates manually, then rerun install.sh."
  fi

  echo "Installing required runtime dependencies: ${RUNTIME_PACKAGES[*]}"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y "${RUNTIME_PACKAGES[@]}"
}

verify_gateway_runtime() {
  local missing
  missing="$(ldd /opt/vigor/bin/gateway | awk '/not found/ { print $1 }')"
  if [ -n "$missing" ]; then
    echo "Missing runtime libraries after installation:" >&2
    printf '  %s\n' $missing >&2
    exit 1
  fi
}

echo "=== Installing Vigor Edge Gateway Daemon ==="

require_root
verify_bundle_files
install_runtime_dependencies

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
cp "$SCRIPT_DIR/bin/gateway" /opt/vigor/bin/gateway
chmod 755 /opt/vigor/bin/gateway
chown -R vigor:vigor /opt/vigor
verify_gateway_runtime

# 4. Install config template if config does not exist
if [ ! -f /etc/vigor/config.json ]; then
  cp "$SCRIPT_DIR/config.json.template" /etc/vigor/config.json
  echo "Installed default config to /etc/vigor/config.json"
fi

# 5. Restrict config file permissions (mode 0640, root:vigor)
chown root:vigor /etc/vigor/config.json
chmod 0640 /etc/vigor/config.json
echo "Protected /etc/vigor/config.json with mode 0640 (root:vigor)"

# 6. Install systemd service
cp "$SCRIPT_DIR/vigor-gateway.service" /etc/systemd/system/vigor-gateway.service
systemctl daemon-reload
systemctl enable vigor-gateway.service

echo "=== Vigor Edge Gateway Daemon Installed Successfully ==="
echo "Next steps:"
echo "1. Edit /etc/vigor/config.json with your Gateway ID, Token, and local RTSP cameras"
echo "2. Start service: sudo systemctl start vigor-gateway"
echo "3. Check logs: sudo journalctl -u vigor-gateway -f"
