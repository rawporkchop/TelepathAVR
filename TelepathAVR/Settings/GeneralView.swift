//
//  GeneralView.swift
//  TelepathAVR
//
//  Created by Oliver Larsson on 1/29/25.
//

import SwiftUI

struct GeneralView: View {
    @AppStorage("zonesEnabled") private var zonesEnabled: Bool = true
    @AppStorage("zoneTapEnabled") private var zoneTapEnabled: Bool = true
    @AppStorage("resizeable") private var resizeable: Bool = true
    @AppStorage("allowsStretching") private var allowsStretching: Bool = true
    
    @AppStorage("zone1VolLimit") private var zone1VolLimit: Double = 80.0
    @AppStorage("zone2VolLimit") private var zone2VolLimit: Double = 80.0
    @AppStorage("zone3VolLimit") private var zone3VolLimit: Double = 80.0
    
    @AppStorage("rotatesWhenExpands") private var rotatesWhenExpands: Bool = true
    
    private let zones: [Zone] = [.one, .two, .three]
    @AppStorage("tempSelectedZone") private var selectedZone: Zone = .one
    @AppStorage("volumeSideButtonsEnabled") private var volumeSideButtonsEnabled = true
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Enable Other Zones With"),
                        footer: Text("Swiping across the background will summon additional volume sliders. Make sure your receiver has multi-zone capability.")) {
                    Toggle("Swipe Gesture to Summon", isOn: $zonesEnabled)
                        .switchFeedback(zonesEnabled)
                }
                
                Section(header: Text("Power-Toggle Zones With"),
                        footer: Text("Double tapping on a volume slider will toggle powered state of their respective zone. Disabling will default to hollistic receiver power toggling.")) {
                    Toggle("Double Tap to Power", isOn: $zoneTapEnabled)
                        .switchFeedback(zoneTapEnabled)
                }
                Section(header: Text("Enable Phone Volume Buttons"),
                        footer: Text("Enabling will allow the use of the volume side buttons to control the volume of the audio receiver. This setting will override external audio that is being played on the device.")) {
                    Toggle("Side Volume Buttons", isOn: $volumeSideButtonsEnabled)
                        .switchFeedback(volumeSideButtonsEnabled)
                    Picker("Effect on Zone", selection: $selectedZone) {
                        ForEach(zones, id: \.self) { zone in
                            Text(zone.alias)
                        }
                    }
                }
                .onChange(of: selectedZone) {
                    UserDefaults.standard.setValue(selectedZone.rawValue, forKey: "selectedZone")
                    TelepathAVRApp.shared.audioSession.setSystemVolume(volume: getVolume(selectedZone) ?? 0)
                }
                
                
                
                Section(header: Text("Customize Dimensions"),
                        footer: Text("Use the resize handle to change the width and height of the volume slider.")) {
                    Toggle("Resize Handle", isOn: $resizeable)
                        .switchFeedback(resizeable)
                }
                
                Section(header: Text("Volume Slider Cosmetics"),
                        footer: Text("Enables the stretching effect when volume value is dragged past upper and lower limits. Disable gain volume slider space.")) {
                    Toggle("Enable Stretch Effect", isOn: $allowsStretching)
                        .switchFeedback(allowsStretching)
                }
                
                Section(header: Text("Volume Limits"),
                        footer: Text("Setting a volume limit may be advantageous in protecting the integrity of your speaker drivers, in the event of a mis-swipe. Limit is imposed solely within the app.")) {
                    Slider(
                        value: $zone1VolLimit,
                        in: 0.5...98.0,
                        step: 0.5,
                        minimumValueLabel: Text("Main  "),
                        maximumValueLabel: Text("\(String(format: "%.1f", zone1VolLimit))"),
                        label: {
                            Text("Main")
                        }
                    )
                    .sensoryFeedback(.increase, trigger: zone1VolLimit)
                    Slider(
                        value: $zone2VolLimit,
                        in: 1.0...98.0,
                        step: 1,
                        minimumValueLabel: Text("Zone2"),
                        maximumValueLabel: Text("\(String(format: "%.1f", zone2VolLimit))"),
                        label: {
                            Text("Zone 2")
                        }
                    )
                    .sensoryFeedback(.increase, trigger: zone2VolLimit)
                    
                    Slider(
                        value: $zone3VolLimit,
                        in: 1.0...98.0,
                        step: 1,
                        minimumValueLabel: Text("Zone3"),
                        maximumValueLabel: Text("\(String(format: "%.1f", zone3VolLimit))"),
                        label: {
                            Text("Zone 3")
                        }
                    )
                    .sensoryFeedback(.increase, trigger: zone3VolLimit)
                }
                
                Section(header: Text("Side Menu Cosmetics"),
                        footer: Text("Using the hamburger menu or swiping will cause the View to be rotated. Disable to simplify.")) {
                    Toggle("Enable Rotation Effect", isOn: $rotatesWhenExpands)
                        .switchFeedback(rotatesWhenExpands)
                }
                
            }
        }
        .navigationTitle("General Settings")
        .onDisappear() {
            print("disappear")
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }
}

extension Notification.Name {
    static let settingsChanged = Notification.Name("settingsChanged")
}

public extension View {
    func switchFeedback(_ enabled: Bool) -> some View {
        modifier(SwitchFeedback(enabled: enabled)) // Apply the SwitchFeedback modifier
    }
}

struct SwitchFeedback: ViewModifier {
    let enabled: Bool
    func body(content: Content) -> some View {
        content.sensoryFeedback(.impact(weight: .medium, intensity: 0.5), trigger: enabled)
    }
}

#Preview {
    NavigationStack {
        GeneralView()
    }
}
