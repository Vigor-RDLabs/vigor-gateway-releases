#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
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

# Parse command line options
VERSION=""
PAIRING_CODE=""
API_URL="https://api.vigorlabs.org"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pair)
      PAIRING_CODE="$2"
      shift 2
      ;;
    --version)
      VERSION="$2"
      shift 2
      ;;
    --api-url)
      API_URL="$2"
      shift 2
      ;;
    *)
      fail "Unknown option: $1"
      ;;
  esac
done

if [ -z "$VERSION" ]; then
  echo "Resolving latest gateway version..."
  VERSION=$(curl -s "https://api.github.com/repos/Vigor-RDLabs/vigor-gateway-releases/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' || echo "")
  if [ -z "$VERSION" ]; then
    VERSION=$(curl -fsSL -o /dev/null -w "%{url_effective}" "https://github.com/Vigor-RDLabs/vigor-gateway-releases/releases/latest" | awk -F'/' '{print $NF}' | tr -d '\r\n' || echo "")
  fi
  if [ -z "$VERSION" ] || [ "$VERSION" = "latest" ]; then
    VERSION="v1.0.10"
  fi
  echo "Latest version resolved: $VERSION"
fi

# Check if running standalone without release bundle files
STANDALONE_MODE=false
if [ ! -f "$SCRIPT_DIR/bin/gateway" ] || [ ! -f "$SCRIPT_DIR/config.json.template" ] || [ ! -f "$SCRIPT_DIR/vigor-gateway.service" ]; then
  STANDALONE_MODE=true
  echo "Standalone mode detected. Downloading Vigor Edge Gateway bundle ($VERSION)..."
fi

if [ "$STANDALONE_MODE" = "true" ]; then
  require_root
  
  TMP_DIR=$(mktemp -d)
  trap 'rm -rf "$TMP_DIR"' EXIT

  TARBALL="vigor-gateway-${VERSION}-linux-x86_64.tar.gz"
  CHECKSUM="${TARBALL}.sha256"

  echo "Downloading tarball..."
  curl -fsSL -o "$TMP_DIR/$TARBALL" "https://github.com/Vigor-RDLabs/vigor-gateway-releases/releases/download/${VERSION}/${TARBALL}"
  curl -fsSL -o "$TMP_DIR/$CHECKSUM" "https://github.com/Vigor-RDLabs/vigor-gateway-releases/releases/download/${VERSION}/${CHECKSUM}"

  echo "Verifying checksum..."
  (cd "$TMP_DIR" && sha256sum -c "$CHECKSUM")

  echo "Extracting release bundle..."
  tar -xzf "$TMP_DIR/$TARBALL" -C "$TMP_DIR"

  SCRIPT_DIR="$TMP_DIR/vigor-gateway-${VERSION}-linux-x86_64"
fi

verify_bundle_files() {
  local required_files=(
    "$SCRIPT_DIR/bin/gateway"
    "$SCRIPT_DIR/config.json.template"
    "$SCRIPT_DIR/vigor-gateway.service"
    "$SCRIPT_DIR/web/static/index.html"
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
if systemctl is-active --quiet vigor-gateway.service 2>/dev/null; then
  echo "Stopping running vigor-gateway service..."
  systemctl stop vigor-gateway.service || true
fi
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
mkdir -p /usr/share/vigor-gateway
chown root:vigor /etc/vigor
chmod 0770 /etc/vigor

# 3. Install binary and web assets
cp "$SCRIPT_DIR/bin/gateway" /opt/vigor/bin/gateway
chmod 755 /opt/vigor/bin/gateway
rm -rf /usr/share/vigor-gateway/web
cp -r "$SCRIPT_DIR/web" /usr/share/vigor-gateway/web
chown -R vigor:vigor /opt/vigor
chown -R vigor:vigor /usr/share/vigor-gateway
verify_gateway_runtime

# 4. Install config template or pair gateway
if [ -n "$PAIRING_CODE" ]; then
  echo "Redeeming pairing code '$PAIRING_CODE' with backend at $API_URL..."
  PAYLOAD=$(printf '{"pairing_code":"%s","name":"%s"}' "$PAIRING_CODE" "$(hostname)")
  
  if ! RESPONSE=$(curl -fsSL -X POST \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" \
    "${API_URL}/v1/gateways/pair" 2>/dev/null); then
    fail "Failed to redeem pairing code. Make sure the pairing code is correct and not expired."
  fi

  GW_ID=$(echo "$RESPONSE" | grep -o '"gateway_id":"[^"]*' | grep -o '[^"]*$')
  GW_TOKEN=$(echo "$RESPONSE" | grep -o '"gateway_token":"[^"]*' | grep -o '[^"]*$')
  CTRL_URL=$(echo "$RESPONSE" | grep -o '"control_url":"[^"]*' | grep -o '[^"]*$')

  if [ -z "$GW_ID" ] || [ -z "$GW_TOKEN" ] || [ -z "$CTRL_URL" ]; then
    fail "Invalid pairing response from backend."
  fi

  echo "Pairing successful! Gateway ID: $GW_ID"
  
  if [ -f /etc/vigor/config.json ]; then
    echo "Warning: Existing configuration found at /etc/vigor/config.json."
    echo "Backing up existing configuration to /etc/vigor/config.json.bak"
    cp /etc/vigor/config.json /etc/vigor/config.json.bak
  fi

  sed -e "s|\"gateway_id\": \"[^\"]*\"|\"gateway_id\": \"$GW_ID\"|g" \
      -e "s|\"gateway_token\": \"[^\"]*\"|\"gateway_token\": \"$GW_TOKEN\"|g" \
      -e "s|\"control_url\": \"[^\"]*\"|\"control_url\": \"$CTRL_URL\"|g" \
      "$SCRIPT_DIR/config.json.template" > /etc/vigor/config.json
  echo "Installed paired config to /etc/vigor/config.json"
elif [ ! -f /etc/vigor/config.json ]; then
  cp "$SCRIPT_DIR/config.json.template" /etc/vigor/config.json
  echo "Installed default config to /etc/vigor/config.json"
fi

# 5. Restrict config file permissions (mode 0640, root:vigor)
chown root:vigor /etc/vigor/config.json
chmod 0640 /etc/vigor/config.json
echo "Protected /etc/vigor/config.json with mode 0640 (root:vigor)"

rm -f /etc/vigor/local_auth.json /etc/vigor/bootstrap_password
echo "Reset local web console password state. The next web visit will require administrator password initialization."

# 6. Install systemd service
cp "$SCRIPT_DIR/vigor-gateway.service" /etc/systemd/system/vigor-gateway.service
if ! grep -q -- '--web-root /usr/share/vigor-gateway/web/static' /etc/systemd/system/vigor-gateway.service; then
  sed -i 's|^ExecStart=/opt/vigor/bin/gateway --config /etc/vigor/config.json$|ExecStart=/opt/vigor/bin/gateway --config /etc/vigor/config.json --web-root /usr/share/vigor-gateway/web/static|' /etc/systemd/system/vigor-gateway.service
fi
if ! grep -q '^AmbientCapabilities=CAP_NET_BIND_SERVICE$' /etc/systemd/system/vigor-gateway.service; then
  sed -i '/^StandardError=journal$/a AmbientCapabilities=CAP_NET_BIND_SERVICE\nCapabilityBoundingSet=CAP_NET_BIND_SERVICE' /etc/systemd/system/vigor-gateway.service
fi
systemctl daemon-reload
systemctl enable vigor-gateway.service

# 7. Start or restart service automatically
if [ -n "$PAIRING_CODE" ] || systemctl is-enabled --quiet vigor-gateway.service 2>/dev/null; then
  echo "Starting Vigor Edge Gateway Daemon..."
  systemctl restart vigor-gateway.service
  systemctl is-active --quiet vigor-gateway.service
fi

echo "=== Vigor Edge Gateway Daemon Installed Successfully ==="
echo "Next steps:"
echo "1. Edit /etc/vigor/config.json with your Gateway ID, Token, and local RTSP cameras (if not paired)"
echo "2. Check service status: sudo systemctl status vigor-gateway"
echo "3. Check logs: sudo journalctl -u vigor-gateway -f"
