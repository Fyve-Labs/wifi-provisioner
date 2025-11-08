#!/usr/bin/env bash
set -euo pipefail

AUTOSTART_SERVICE="wifi-provisioner-autostart.service"

case "$1" in
    configure)
      # Enable a soft-blocked Bluetooth device on a Raspberry Pi
      sudo rfkill unblock bluetooth

      # Enable service and keep track of its state
      if deb-systemd-helper --quiet was-enabled "$AUTOSTART_SERVICE"; then
        deb-systemd-helper enable "$AUTOSTART_SERVICE" >/dev/null || true
      fi

      # Bounce service
      if [ -d /run/systemd/system ]; then
        systemctl --system daemon-reload >/dev/null || true
      fi
    ;;

    abort-upgrade|abort-remove|abort-deconfigure)
    ;;

    *)
        echo "postinstall called with unknown argument '$1'" >&2
        exit 1
    ;;
esac
