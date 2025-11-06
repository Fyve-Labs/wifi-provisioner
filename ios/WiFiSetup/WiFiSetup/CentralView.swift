//
//  CentralView.swift
//  Tessa
//
//  Created by Viet Pham on 5/11/25.
//

import SwiftUI
import CoreBluetooth

struct CentralView: View {
    @StateObject private var viewModel = CentralViewModel()
    @State private var ssid = ""
    @State private var password = ""

    var body: some View {
        NavigationView {
            VStack {
                Text("Near by Devices")
                    .font(.title)
                    .padding()
                
                List(viewModel.discoveredPeripherals, id: \.self) { peripheral in
                    Button(action: {
                        viewModel.connect(to: peripheral)
                    }) {
                        Text(peripheral.name ?? "Unknown Device")
                    }
                }
                
                Text("Status: \(viewModel.connectionStatus)")
                    .padding()

                TextField("SSID", text: $ssid)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()

                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()

                Button("Send Credentials") {
                    viewModel.sendWiFiCredentials(ssid: ssid, password: password)
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .navigationTitle("WiFi Setup")
        }
    }
}
