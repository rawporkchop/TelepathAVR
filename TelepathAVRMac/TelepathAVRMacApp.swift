//
//  TelepathAVRMacApp.swift
//  TelepathAVRMac
//
//  Created by Oliver Larsson on 4/29/25.
//

import SwiftUI
import ServiceManagement

@main
struct TelepathAVRMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    static let shared = TelepathAVRMacApp()
    
    let selectedReceiver = SelectedReceiver.shared
    let connection = Connection.shared
    
    init() {

        if UserDefaults.standard.bool(forKey: "AppAlreadyLaunchedOnce") == false {
            
            UserDefaults.standard.setValue(true, forKey: "AppAlreadyLaunchedOnce")
            
            UserDefaults.standard.setValue(80.0, forKey: "zone1VolLimit")
            UserDefaults.standard.setValue(80.0, forKey: "zone2VolLimit")
            UserDefaults.standard.setValue(80.0, forKey: "zone3VolLimit")
        
            UserDefaults.standard.setValue(Zone.one.rawValue, forKey: "selectedZone")
            
            selectedReceiver.receiver = SimpleEndpoint.demoReceiver
        }
        
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to set launch at login: \(error)")
        }
    }
    
    var body: some Scene {
        Settings {
            EmptyView() // No settings UI
        }
    }
}

