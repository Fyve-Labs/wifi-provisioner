//
//  CentralViewModel.swift
//  Tessa
//
//  Created by Viet Pham on 5/11/25.
//

import Foundation
import CoreBluetooth
import Combine

final class CentralViewModel: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var discoveredPeripherals = [CBPeripheral]()
    @Published var connectionStatus = "Disconnected"

    private var centralManager: CBCentralManager!
    private var targetPeripheral: CBPeripheral?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            startScan()
        } else {
            print("Bluetooth is not available.")
        }
    }

    func startScan() {
        centralManager.scanForPeripherals(withServices: [WiFiProvisioningService.serviceUUID], options: nil)
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if !discoveredPeripherals.contains(peripheral) {
            discoveredPeripherals.append(peripheral)
        }
    }

    func connect(to peripheral: CBPeripheral) {
        centralManager.stopScan()
        targetPeripheral = peripheral
        targetPeripheral?.delegate = self
        centralManager.connect(peripheral, options: nil)
        connectionStatus = "Connecting..."
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectionStatus = "Connected"
        peripheral.discoverServices([WiFiProvisioningService.serviceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectionStatus = "Failed to connect"
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func sendWiFiCredentials(ssid: String, password: String) {
        guard let peripheral = targetPeripheral,
              let services = peripheral.services,
              let service = services.first(where: { $0.uuid == WiFiProvisioningService.serviceUUID }) else {
            return
        }

        let characteristics = service.characteristics ?? []
        
        if let ssidCharacteristic = characteristics.first(where: { $0.uuid == WiFiProvisioningService.ssidCharacteristicUUID }),
           let ssidData = ssid.data(using: .utf8) {
            peripheral.writeValue(ssidData, for: ssidCharacteristic, type: .withResponse)
        }

        if let passwordCharacteristic = characteristics.first(where: { $0.uuid == WiFiProvisioningService.passwordCharacteristicUUID }),
           let passwordData = password.data(using: .utf8) {
            peripheral.writeValue(passwordData, for: passwordCharacteristic, type: .withResponse)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error writing characteristic value: \(error.localizedDescription)")
            return
        }
        print("Successfully wrote value for \(characteristic.uuid)")
    }
}
