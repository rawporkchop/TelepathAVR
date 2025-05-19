//
//  StatusPopoverView.swift
//  TelepathAVR
//
//  Created by Oliver Larsson on 4/29/25.
//

import SwiftUI


struct StatusPopoverView: View {
    @ObservedObject var connection = Connection.shared
    @StateObject private var selectedReceiver = TelepathAVRMacApp.shared.selectedReceiver
    @State private var showMenu: Bool = false
    let cornerRadius: CGFloat = 12
    
    @State private var showZ1Settings: Bool = false
    @State private var showZ2Settings: Bool = false
    @State private var showZ3Settings: Bool = false
    @State private var clientSelectedInput: [InputDevice] = [.select, .select, .select]
    func showSetting(_ zone: Zone) -> Bool {
        switch zone {
        case .one: return showZ1Settings
        case .two: return showZ2Settings
        case .three: return showZ3Settings
        }
    }

    func showSettings(_ zone: Zone) {
        switch zone {
        case .one: showZ1Settings.toggle()
        case .two: showZ2Settings.toggle()
        case .three: showZ3Settings.toggle()
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text((connection.isDemoActive ? "Demo" : selectedReceiver.receiver?.name.prefix(20)) ?? "Disconnected")
                    .font(.headline)
                    .padding(.horizontal, 5)
                Spacer(minLength: 0)
                Button(action: { showMenu.toggle() }) {
                    Image(systemName: showMenu ? "xmark" : "line.3.horizontal")
                        .frame(width: 10, height: 5)
                        .contentTransition(.symbolEffect)
                }
            }
            if !showMenu {
                sliders()
            }
            else {
                ReceiversView()
            }
        }
        .onAppear {
            initializeApp()
        }
        .onChange(of: clientSelectedInput) { oldValue, newValue in
            let indexChanged: Int? = zip(oldValue, newValue).enumerated().first(where: { _, pair in
                pair.0 != pair.1
            })?.offset

            print("found index \(String(describing: indexChanged))")
            connection.setInputDevice(newValue[indexChanged ?? 0], indexChanged ?? 0)
        }
//        .onChange(of: connection.selectedInput) {
//            clientSelectedInput = connection.selectedInput
//        }
        .frame(minWidth: 280)
        .padding(10)
        .background(.ultraThinMaterial.opacity(0.4))
        .background(
            GeometryReader { proxy in
                Color.clear
                .onChange(of: proxy.size) {
                    if let window = NSApp.keyWindow {
                        window.setContentSize(proxy.size)
                    }
                }
            }
        )
        .onWindowDidAppear { window in
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    private func initializeApp() {
        guard !connection.isConnected else { return }
        connection.start(receiver: selectedReceiver.receiver)
    }
    
    
    func sliders() -> some View {
        ForEach(connection.zones.compactMap {$0}) { zone in
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    Text(showSetting(zone) ? "Max Volume" : zone.alias)
                        .font(.headline)
                    Spacer(minLength: 0)
                    Picker("", selection: $clientSelectedInput[zone.index]) {
                        ForEach (InputDevice.allCases, id: \.self) { device in
                            Text(device.rawValue).tag(device)
                        }
                        
                    }
                    .frame(maxWidth: 70)
                    .buttonStyle(.borderless)
                    Button {
                        showSettings(zone)
                    } label: {
                        Image(systemName: "gear.circle.fill")
                            .font(.title2)
                            .foregroundStyle(showSetting(zone) ? .blue : .white)
                    }
                    .buttonStyle(.plain)
                    Button {
                        connection.zoneToggle(zone)
                    } label: {
                        Image(systemName: "power.circle.fill")
                            .font(.title2)
                            .foregroundStyle(connection.getPowerState(zone) ? .blue : .white)
                    }
                    .buttonStyle(.plain)
                    
                }
                .padding(.vertical, 8)
                
                if !showSetting(zone) {
                    VolumeSlider(zone: zone)
                        .frame(height: 20)
                        .disabled(!connection.getPowerState(zone))
                        .opacity(connection.getPowerState(zone) ? 1 : 0.5)
                }
                else {
                    MaxVolumeSlider(zone: zone)
                        .frame(height: 20)
                }
                
                
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 12)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 0.8)
            )
            
        }
    }
}


