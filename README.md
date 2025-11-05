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

## Stack
- Language: Go (module mode)
- Go version: 1.25 (per go.mod)
- Package manager: Go modules (go.mod, go.sum)
- Libraries:
  - `tinygo.org/x/bluetooth` (used for BLE; works on Linux via BlueZ)
- Runtime/OS expectations:
  - Linux with BlueZ (for BLE) and NetworkManager (`nmcli`) available
- Entry point: `main.go` (package `main`)

## Requirements
- Hardware: Linux host with BLE (e.g., Raspberry Pi with onboard Bluetooth or a USB BLE dongle)
- OS/software:
  - BlueZ (Bluetooth stack)
  - NetworkManager with `nmcli`
  - Go 1.25+ toolchain
- Permissions:
  - BLE advertising and `nmcli` often require elevated privileges. Simplest is to run the binary with `sudo`.
  - Alternatively, you may experiment with capabilities (example):
    - `sudo setcap cap_net_raw,cap_net_admin+eip ./wifi-provisioner`
    - You might still need permissions for `nmcli` under PolicyKit; running with `sudo` is usually easiest.

## Install (Linux arm64)
You can install the prebuilt Linux arm64 binary directly from GitHub Releases using this one-liner:

```bash
curl -fsSL https://raw.githubusercontent.com/Fyve-Labs/wifi-provisioner/main/install.sh | sudo sh
```

- This installs to /usr/local/bin by default. It fetches the latest release for linux/arm64.
- To install a specific version (example v1.2.3):
  ```bash
  curl -fsSL https://raw.githubusercontent.com/Fyve-Labs/wifi-provisioner/main/install.sh | sudo VERSION=v1.2.3 sh
  ```
- Without sudo (install to a writable directory):
  ```bash
  BIN_DIR="$HOME/.local/bin" NO_SUDO=1 curl -fsSL https://raw.githubusercontent.com/Fyve-Labs/wifi-provisioner/main/install.sh | sh
  ```
- Checksums are verified against the release checksums.txt by default. To skip verification set VERIFY=0.

If you prefer to build from source, follow the steps below.

## Setup
1. Install Go 1.25+.
2. Ensure BlueZ and NetworkManager (`nmcli`) are installed and running.
3. Clone and build:
   ```bash
   git clone <your-repo-url>.git
   cd wifi-provisioner2
   go build -o wifi-provisioner ./
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

### Mobile app pairing flow
- Open your app and scan for devices; select `PiZero-WiFi-Setup`.
- Write the SSID to characteristic `B1B0AC35-A253-4258-A5A5-A2A6A928B03B`.
- Write the password to characteristic `C2C1BD48-B363-4369-B2B9-B3B8B5B6B4B3`.
- On success, the device should attempt to join the network. Consider rebooting to ensure all services pick up the change.

## Configuration
- The app name and UUIDs are hardcoded in `main.go`.
- Network connection is performed by `nmcli` using the received SSID/password.

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
- Common commands:
  - Build: `go build -o wifi-provisioner ./`
  - Run: `sudo ./wifi-provisioner`
- TODO: Add helper scripts (e.g., `make run`, `make build`, systemd unit file) if desired.

## Tests
- There are no automated tests in this repository as of 2025-11-05.
- Manual validation steps:
  1. Start the program and confirm logs show advertising started.
  2. From the mobile app, write SSID and password; confirm logs indicate both were received.
  3. Check the output of the `nmcli` command in logs.
  4. Verify the device connects to the target Wi‑Fi (`nmcli connection show --active`).
- TODO: Introduce unit tests (e.g., factoring out `configureWiFi` to allow command injection/mocking) and BLE interaction tests via interfaces.

## Project structure
```
/ (repo root)
├── go.mod
├── go.sum
└── main.go     # Entry point: BLE advertise + credentials handling + nmcli call
```

## Troubleshooting
- Advertising fails or permission errors:
  - Try running with `sudo`.
  - Ensure BlueZ is installed and the Bluetooth service is running.
- `nmcli` fails with errors:
  - Check that the SSID is in range; verify password.
  - Review stderr printed by the program on failure.
- Cannot see the device from phone:
  - Power-cycle Bluetooth, ensure no other process is advertising with the same adapter.
  - Ensure your phone supports BLE and the app uses the exact UUIDs listed above.

## Security notes
- Password is not logged, but it is passed as a command argument to `nmcli`. On some systems, process arguments may be visible to other users. Running on a single-purpose device (e.g., provisioner on a Pi) mitigates risk. Consider alternatives (e.g., stdin or files with restricted permissions) if needed.

## License
- No license file found.
- TODO: Add a LICENSE file (e.g., MIT/Apache-2.0). Until then, usage terms are unspecified.

## Roadmap / Ideas
- Optional environment configuration for device name and UUIDs
- Systemd service unit to run at boot until provisioned
- Retry/backoff and better status feedback over BLE
- Optional TinyGo build targets for MCUs (if applicable)

## Acknowledgements
- BLE functionality is provided by `tinygo.org/x/bluetooth`.

---
Last updated: 2025-11-05