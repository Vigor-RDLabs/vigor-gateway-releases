#!/bin/bash
set -euo pipefail

fail() {
  echo "Error: $*" >&2
  exit 1
}

require_root() {
  if [ "$EUID" -ne 0 ]; then
    fail "Please run uninstall.sh as root (sudo ./uninstall.sh)"
  fi
}

echo "=== Uninstalling Vigor Edge Gateway Daemon ==="

require_root

# Parse arguments
PURGE_CONFIG=false
for arg in "$@"; do
  if [ "$arg" = "--purge" ]; then
    PURGE_CONFIG=true
  fi
done

# 1. Stop and disable systemd service
SERVICE_NAME="vigor-gateway.service"
if systemctl list-unit-files "$SERVICE_NAME" >/dev/null 2>&1; then
  echo "Stopping and disabling service '$SERVICE_NAME'..."
  systemctl stop "$SERVICE_NAME" || true
  systemctl disable "$SERVICE_NAME" || true
fi

# 2. Remove systemd service file
SERVICE_FILE="/etc/systemd/system/vigor-gateway.service"
if [ -f "$SERVICE_FILE" ]; then
  echo "Removing systemd service file..."
  rm -f "$SERVICE_FILE"
  systemctl daemon-reload
fi

# 3. Remove binary and libraries
if [ -d "/opt/vigor" ]; then
  echo "Removing binary and installation files from /opt/vigor..."
  rm -rf "/opt/vigor"
fi

# 4. Remove logs
if [ -d "/var/log/vigor" ]; then
  echo "Removing service logs from /var/log/vigor..."
  rm -rf "/var/log/vigor"
fi

# 5. Remove system user 'vigor'
if id -u vigor >/dev/null 2>&1; then
  echo "Removing system user 'vigor'..."
  userdel vigor || echo "Warning: Failed to delete user 'vigor'. Continuing."
fi

# 6. Remove configuration files (only if --purge is specified)
if [ -d "/etc/vigor" ]; then
  if [ "$PURGE_CONFIG" = true ]; then
    echo "Purging configuration files from /etc/vigor..."
    rm -rf "/etc/vigor"
  else
    echo "Configuration files left in /etc/vigor (run with '--purge' to delete)."
  fi
fi

echo "=== Vigor Edge Gateway Daemon Uninstalled Successfully ==="
