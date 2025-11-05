package main

import (
	"fmt"
	"log"
	"os/exec"
	"time"

	"tinygo.org/x/bluetooth"
)

// Use the exact same UUIDs defined in the iOS application.
const (
	serviceUUIDString                = "A0A8E453-562A-49A3-A2E4-29A8E88B0E9B"
	ssidCharacteristicUUIDString     = "B1B0AC35-A253-4258-A5A5-A2A6A928B03B"
	passwordCharacteristicUUIDString = "C2C1BD48-B363-4369-B2B9-B3B8B5B6B4B3"
)

var (
	// These variables will hold the credentials received over BLE.
	receivedSSID     []byte
	receivedPassword []byte

	// Use a channel to signal when both credentials have been received.
	credentialsReceived = make(chan bool)
)

func main() {
	// We use the default Bluetooth adapter on the Raspberry Pi.
	adapter := bluetooth.DefaultAdapter

	log.Println("1. Enabling Bluetooth adapter...")
	must("enable BLE stack", adapter.Enable())

	// Define the service UUID.
	serviceUUID, err := bluetooth.ParseUUID(serviceUUIDString)
	must("parse service UUID", err)

	// Define the SSID characteristic.
	ssidCharacteristicUUID, err := bluetooth.ParseUUID(ssidCharacteristicUUIDString)
	must("parse SSID characteristic UUID", err)

	// Define the Password characteristic.
	passwordCharacteristicUUID, err := bluetooth.ParseUUID(passwordCharacteristicUUIDString)
	must("parse password characteristic UUID", err)

	log.Println("2. Setting up BLE service and characteristics...")

	// Build the advertisement payload.
	adv := adapter.DefaultAdvertisement()
	must("configure advertisement", adv.Configure(bluetooth.AdvertisementOptions{
		LocalName:    "PiZero-WiFi-Setup", // This name will be visible on the iOS app.
		ServiceUUIDs: []bluetooth.UUID{serviceUUID},
	}))

	// Add the service with its characteristics.
	must("add BLE service", adapter.AddService(&bluetooth.Service{
		UUID: serviceUUID,
		Characteristics: []bluetooth.CharacteristicConfig{
			{
				// SSID Characteristic
				UUID:  ssidCharacteristicUUID,
				Value: receivedSSID,
				Flags: bluetooth.CharacteristicWritePermission, // Allow writing.
				// Define a callback for when this characteristic is written to.
				WriteEvent: func(client bluetooth.Connection, offset int, value []byte) {
					log.Printf("Received SSID: %s", string(value))
					receivedSSID = value
					checkCredentialsComplete()
				},
			},
			{
				// Password Characteristic
				UUID:  passwordCharacteristicUUID,
				Value: receivedPassword,
				Flags: bluetooth.CharacteristicWritePermission, // Allow writing.
				// Define a callback for when this characteristic is written to.
				WriteEvent: func(client bluetooth.Connection, offset int, value []byte) {
					log.Println("Received password.") // Avoid logging the actual password for security.
					receivedPassword = value
					checkCredentialsComplete()
				},
			},
		},
	}))

	log.Println("3. Starting BLE advertisement...")
	must("start advertising", adv.Start())
	log.Println("   ...waiting for connection. Open the iOS app to scan.")

	// Block until the credentialsReceived channel receives a signal.
	<-credentialsReceived

	log.Println("4. Both SSID and Password received. Stopping advertisement.")
	must("stop advertising", adv.Stop())

	// Small delay to allow BLE operations to finalize.
	time.Sleep(1 * time.Second)

	log.Println("5. Attempting to configure Wi-Fi...")
	err = configureWiFi(string(receivedSSID), string(receivedPassword))
	if err != nil {
		log.Fatalf("!!! Failed to configure Wi-Fi: %v", err)
	}

	log.Println("✅ Success! Wi-Fi has been configured.")
	log.Println("   The Raspberry Pi should now connect to the new network.")
	log.Println("   You can reboot the device with 'sudo reboot' to ensure changes apply.")
}

// checkCredentialsComplete checks if both SSID and password have been populated.
// If they have, it sends a signal to the main goroutine to proceed.
func checkCredentialsComplete() {
	if len(receivedSSID) > 0 && len(receivedPassword) > 0 {
		// Non-blocking send in case it's called multiple times.
		select {
		case credentialsReceived <- true:
		default:
		}
	}
}

// configureWiFi takes the credentials and applies them to the system.
func configureWiFi(ssid, password string) error {
	log.Printf("   -> Executing: nmcli device wifi connect \"%s\" password \"%s\"", ssid, password)

	// The command is `nmcli` with arguments `device wifi connect <SSID> password <PASSWORD>`
	// We run this command directly. Since the Go program is run with `sudo`,
	// this command will also have root privileges.
	cmd := exec.Command("nmcli", "device", "wifi", "connect", ssid, "password", password)

	// `CombinedOutput` captures both stdout and stderr, which is useful for debugging.
	output, err := cmd.CombinedOutput()
	if err != nil {
		// If the command fails, we return an error that includes the output from nmcli.
		// This helps diagnose issues like incorrect passwords or out-of-range networks.
		return fmt.Errorf("nmcli command failed: %s\nError: %w", string(output), err)
	}

	log.Printf("   -> nmcli command successful. Output:\n%s", string(output))
	return nil
}

// must is a helper function that panics if an error is not nil.
func must(action string, err error) {
	if err != nil {
		panic("failed to " + action + ": " + err.Error())
	}
}
