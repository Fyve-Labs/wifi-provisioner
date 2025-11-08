#!/usr/bin/env bash
set -euo pipefail

# postinstall for wifi-provisioner .deb
# Reload systemd units so newly installed service files are recognized.
if command -v systemctl >/dev/null 2>&1; then
  systemctl daemon-reload || true
  echo "[wifi-provisioner] Installed systemd units. You may enable autostart with:\n  sudo systemctl enable --now wifi-provisioner-autostart.service"
fi

# Ensure helper script is executable (should already be via dpkg, but just in case)
if [ -f /usr/local/bin/check-connectivity-and-provision.sh ]; then
  chmod 755 /usr/local/bin/check-connectivity-and-provision.sh || true
fi
