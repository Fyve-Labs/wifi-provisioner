#!/usr/bin/env bash
set -euo pipefail

LOG_TAG="wifi-provisioner-autostart"
PROVISIONER_BIN="/usr/local/bin/wifi-provisioner"

# How we decide "internet is up": ping once with a short timeout.
# You can change 1.1.1.1 to any reliable IP or even a hostname (adds DNS dependency).
PING_TARGET="1.1.1.1"
PING_TIMEOUT=3

log() { logger -t "$LOG_TAG" -- "$*"; echo "$LOG_TAG: $*"; }

# If the provisioner binary isn’t installed yet, do nothing.
if [[ ! -x "$PROVISIONER_BIN" ]]; then
  log "Provisioner binary not found at $PROVISIONER_BIN; skipping"
  exit 0
fi

# If we’re already online, do nothing.
if ping -c1 -W "$PING_TIMEOUT" "$PING_TARGET" >/dev/null 2>&1; then
  log "Internet is reachable; not starting provisioner"
  exit 0
fi

# Optional: also check NetworkManager’s view (fast path), but don’t rely solely on it.
if command -v nmcli >/dev/null 2>&1; then
  STATE=$(nmcli -t -f STATE general status 2>/dev/null | head -n1 || true)
  if [[ "$STATE" == "connected" || "$STATE" == "connected (site only)" ]]; then
    log "nmcli reports connected, but ping failed; not starting provisioner"
    exit 0
  fi
fi

# No internet — launch the provisioner.
log "No internet; starting provisioner binary directly"
exec "$PROVISIONER_BIN"
