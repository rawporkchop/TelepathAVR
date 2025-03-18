//
//  Receivers.swift
//  TelepathAVR
//
//  Created by Oliver Larsson on 1/16/25.
//

import SwiftUI


struct ReceiversView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var selectedReceiver = TelepathAVRApp.shared.selectedReceiver
    @StateObject private var browser = Browser()
    @StateObject var connection: Connection = TelepathAVRApp.shared.connection
    
    @State private var manualAlert = false
    @State private var tempName: String = ""
    @State private var tempIP: String = ""

    var body: some View {
        
        VStack {
            Text("Select Receiver")
                .font(.title.bold())
                .padding(20)
            
            List {
                ForEach(Array(browser.endpoints)) { receiver in
                    HStack {
                        Image(systemName: "checkmark")
                            .visible(receiver == selectedReceiver.receiver)
                        Button(receiver.name.prefix(40)) {
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
                HStack {
                    Image(systemName: "checkmark")
                        .visible(selectedReceiver.isDemo())
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
                
            }
            .frame(maxWidth: 500)
            HStack() {
                Spacer(minLength: 0)
            }
            
            Spacer(minLength: 0)
            
            HStack(spacing: 2) {
                sheetButton(.rediscover) {
                    selectedReceiver.erase()
                    UserDefaults.standard.set([], forKey: "savedEndpoints")
                    connection.stop()

                    browser.restart()
                }
                sheetButton(.manual) {
                    manualAlert = true
                }
                sheetButton(.dismiss) {
                    dismiss()
                }
            }
            .padding(.vertical, 10)
        }
        .alert("Add Receiver Manually", isPresented: $manualAlert) {
            TextField("Alias (Optional)", text: $tempName)
            TextField("IP or DNS", text: $tempIP)

            Button("Cancel") {
                manualAlert = false
                tempName = ""
                tempIP = ""
            }
            Button("Continue") {
                manualAlert = false
                if !tempIP.isEmpty {
                let manualReceiver: SimpleEndpoint = .init(
                    name: tempName.isEmpty ? tempIP
                    : tempName, localDNS
                    : tempIP
                )
                    
                    browser.endpoints.insert(manualReceiver)
                    selectedReceiver.change(to: manualReceiver)
                    connection.start(receiver: manualReceiver)
                }
                tempName = ""
                tempIP = ""

            }
        } message: {
            Text("Please enter an alias (optional) and the IP or DNS of the AVR Receiver")
        }
        .onAppear {
            browser.start()
        }
        .onDisappear {
            browser.close()
        }
    }
    
    func sheetButton(_ tab: Tab, onTap: @escaping () -> () = {  } ) -> some View {
        
        Button(action: onTap, label: {
            Text(tab.title)
                .padding(.vertical, 15)
                .foregroundColor(.pink)
                .frame(minWidth: CGFloat(Tab.maxLength() * 15))
                .background(

                    RoundedRectangle(
                        cornerRadius: 20,
                        style: .continuous
                    )
                    .fill(.pink.opacity(0.2))
                )
        })

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

#Preview {
    ContentView()
}
