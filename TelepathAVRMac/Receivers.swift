//
//  Receivers.swift
//  TelepathAVR
//
//  Created by Oliver Larsson on 5/4/25.
//

import SwiftUI


struct ReceiversView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var selectedReceiver = TelepathAVRMacApp.shared.selectedReceiver
    @StateObject private var browser = Browser()
    @StateObject var connection: Connection = TelepathAVRMacApp.shared.connection
    
    @State private var manualAlert = false
    @State private var tempName: String = ""
    @State private var enteredIP: String = ""
    @State private var tempIP: String = ""
    @FocusState private var isFocused: Bool
    @AppStorage("startOnLogin") var startOnLogin: Bool = false

    var body: some View {
        
        VStack(alignment: .leading) {
            Text("Select Receiver")
                .font(.headline)
                .offset(x: 4)
            
            List {
                HStack {
                    if selectedReceiver.isDemo() {
                        Image(systemName: "checkmark")
                    }
                    Button(SimpleEndpoint.demoReceiver!.name.prefix(40)) {
                        if selectedReceiver.isDemo() {
                            connection.isDemoActive = false

                            selectedReceiver.change(to: nil)
                            connection.stop()
                        }
                        else {
                            selectedReceiver.change(to: SimpleEndpoint.demoReceiver)
                            
                            connection.start(receiver: selectedReceiver.receiver)
 
                        }
                    }
                }
                ForEach(Array(browser.endpoints)) { receiver in
                    HStack {
                        if receiver == selectedReceiver.receiver {
                            Image(systemName: "checkmark")
                        }
                        Button(receiver.name.prefix(30)) {
                            if receiver == selectedReceiver.receiver {
                                selectedReceiver.change(to: nil)
                                connection.stop()
                                
                            }
                            else {
                                selectedReceiver.change(to: receiver)
                                connection.start(receiver: receiver)
                                
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: 500, minHeight: 170)
            .scrollContentBackground(.hidden)
            .background(.ultraThinMaterial.opacity(0.4))
            .cornerRadius(10)
            
            Toggle("Start on Login", isOn: $startOnLogin)
                .onChange(of: startOnLogin) {
                    TelepathAVRMacApp.shared.setLaunchAtLogin(startOnLogin)
                }
            
            HStack() {
                TextField(
                    enteredIP.isEmpty ? "Enter IP or DNS" : "Enter an Alias",
                    text: enteredIP.isEmpty ? $tempIP : $tempName,
                    onCommit: {
                        if enteredIP.isEmpty {
                            enteredIP = tempIP
                            isFocused = true
                        } else {
                            if !tempIP.isEmpty {
                                let manualReceiver: SimpleEndpoint = .init(
                                    name: tempName.isEmpty ? enteredIP : tempName,
                                    localDNS: enteredIP
                                )

                                browser.endpoints.insert(manualReceiver)
                                selectedReceiver.change(to: manualReceiver)
                                connection.start(receiver: manualReceiver)
                            }

                            tempName = ""
                            tempIP = ""
                            enteredIP = ""
                            isFocused = false
                        }
                    }
                )
                .focused($isFocused)
                .onAppear {
                    isFocused = true
                }

                Spacer(minLength: 6)
                
                Button("Rediscover") {
                    
                    selectedReceiver.erase()
                    UserDefaults.standard.set([], forKey: "savedEndpoints")
                    connection.stop()
                    
                    browser.restart()
                }
            }
        }
    
        .onAppear {
            browser.start()
        }
        .onDisappear {
            browser.close()
        }
    }
    
    enum Tab: String, CaseIterable {
        case rediscover
        case manual
        case dismiss
        
        var title: String {
            switch self {
            case .rediscover: return "Discover"
            case .manual: return "Enter IP"
            case .dismiss: return "Dismiss"
            }
        }
        
        static func maxLength() -> Int {
            return (Tab.allCases.max{ $0.title.count < $1.title.count }!).title.count
        }
    }
}
