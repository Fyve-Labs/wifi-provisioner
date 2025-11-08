# Wi‑Fi Provisioner (BLE → nmcli)

A minimal Go application that advertises a Bluetooth LE (BLE) service to receive Wi‑Fi credentials (SSID and password) from a companion mobile app, then configures the device’s Wi‑Fi using NetworkManager (`nmcli`). Intended for Raspberry Pi OS or other Linux systems with BlueZ and NetworkManager.

Device advertises as: `PiZero-WiFi-Setup`

Service/characteristics UUIDs (must match the mobile app):
- Service: `A0A8E453-562A-49A3-A2E4-29A8E88B0E9B`
- SSID characteristic: `B1B0AC35-A253-4258-A5A5-A2A6A928B03B`
- Password characteristic: `C2C1BD48-B363-4369-B2B9-B3B8B5B6B4B3`

When both SSID and password are written over BLE, the app stops advertising and runs:

```
nmcli device wifi connect <SSID> password <PASSWORD>
```

## Install via .deb (Debian/Ubuntu)
We publish a .deb package that installs the binary and boot-time autostart components.

Install:
```bash
wget https://github.com/Fyve-Labs/wifi-provisioner/releases/download/v0.0.3/wifi-provisioner_0.0.3_arm64.deb
sudo dpkg -i wifi-provisioner_0.0.3_arm64.deb
```

## Install via script (Linux arm64)
If you don’t use Debian packages, you can install the prebuilt Linux arm64 binary directly from GitHub Releases using this one-liner:

```bash
curl -fsSL https://raw.githubusercontent.com/Fyve-Labs/wifi-provisioner/main/install.sh | sudo sh
```

## Run
- Run with sudo so BLE advertise and nmcli can work without extra configuration:
  ```bash
  sudo ./wifi-provisioner
  ```
- The program will:
  - Enable BLE adapter
  - Advertise the custom service with the device name `PiZero-WiFi-Setup`
  - Wait for a client (your mobile app) to write SSID and password
  - Stop advertising and invoke `nmcli` to connect

## How the autostart keeps your device online
This repository includes a simple boot-time mechanism that starts provisioning only when the device is offline. It is designed to be hands-off for normal operation and to automatically help you recover connectivity.

- At boot, systemd runs wifi-provisioner-autostart.service, which executes /usr/local/bin/check-connectivity-and-provision.sh.
- The helper quickly pings a well-known IP (1.1.1.1) to determine whether the device has internet.
- If internet is reachable, it exits and nothing else runs.
- If the device is offline, it launches the wifi-provisioner binary directly so you can provision over BLE.

Recommended workflow when connectivity is lost:
- Reboot the device. On the next boot, since there is no connectivity yet, the autostart helper will start the provisioner automatically.
- Use the mobile app to send new Wi‑Fi credentials.
- Once the device connects, future boots will skip starting the provisioner (because internet is up).

Notes:
- If you want the system to also auto-recover during runtime link drops (without reboot), you can add your own NetworkManager dispatcher script that calls the helper on down/disconnected events.

### Mobile app pairing flow
- Open your app and scan for devices; select `PiZero-WiFi-Setup`.
- Write the SSID to characteristic `B1B0AC35-A253-4258-A5A5-A2A6A928B03B`.
- Write the password to characteristic `C2C1BD48-B363-4369-B2B9-B3B8B5B6B4B3`.
- On success, the device should attempt to join the network. Consider rebooting to ensure all services pick up the change.

## Environment variables
- None currently.
- TODO: Consider adding env vars for:
  - Device name advertised over BLE
  - Service/characteristic UUID overrides
  - Log verbosity

## Scripts
- install.sh: install the prebuilt linux/arm64 binary from GitHub Releases into your PATH. See the Install section for curl | sh usage.
- release.sh: calculate next version from Fyve-Labs/wifi-provisioner tags and create/push a new tag to trigger GitHub Release.
  - Usage:
    - ./release.sh [patch|minor|major] [-y] [--no-push] [--dry-run]
    - Default bump is patch. Use -y to skip confirmation.
    - Example: ./release.sh minor -y

## Security notes
- Password is not logged, but it is passed as a command argument to `nmcli`. On some systems, process arguments may be visible to other users. Running on a single-purpose device (e.g., provisioner on a Pi) mitigates risk. Consider alternatives (e.g., stdin or files with restricted permissions) if needed.

## Acknowledgements
- BLE functionality is provided by `tinygo.org/x/bluetooth`.

---
Last updated: 2025-11-08