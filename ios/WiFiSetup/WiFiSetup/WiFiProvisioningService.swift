//
//  WiFiProvisioningService.swift
//  Tessa
//
//  Created by Viet Pham on 5/11/25.
//

import Foundation
import CoreBluetooth

struct WiFiProvisioningService {
    static let serviceUUID = CBUUID(string: "A0A8E453-562A-49A3-A2E4-29A8E88B0E9B")
    static let ssidCharacteristicUUID = CBUUID(string: "B1B0AC35-A253-4258-A5A5-A2A6A928B03B")
    static let passwordCharacteristicUUID = CBUUID(string: "C2C1BD48-B363-4369-B2B9-B3B8B5B6B4B3")
}
