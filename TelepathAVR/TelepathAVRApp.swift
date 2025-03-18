//
//  TelepathAVRApp.swift
//  TelepathAVR
//
//  Created by Oliver Larsson on 1/12/25.
//

import SwiftUI

@main
struct TelepathAVRApp: App {
    static let shared = TelepathAVRApp()
    
    let selectedReceiver = SelectedReceiver.shared
    let connection = Connection.shared
    let audioSession = AudioSession.shared
    
    init() {
        
        if UserDefaults.standard.bool(forKey: "AppAlreadyLaunchedOnce") == false {
            
            UserDefaults.standard.setValue(true, forKey: "AppAlreadyLaunchedOnce")
            copyFileToDocuments(fileName: "ColorPresets", fileExtension: "json")
            
            
            UserDefaults.standard.setValue(true, forKey: "zonesEnabled")
            UserDefaults.standard.setValue(true, forKey: "zoneTapEnabled")
            UserDefaults.standard.setValue(true, forKey: "resizeable")
            UserDefaults.standard.setValue(true, forKey: "allowsStretching")
            
            UserDefaults.standard.setValue(80.0, forKey: "zone1VolLimit")
            UserDefaults.standard.setValue(80.0, forKey: "zone2VolLimit")
            UserDefaults.standard.setValue(80.0, forKey: "zone3VolLimit")
            
            UserDefaults.standard.setValue(true, forKey: "rotatesWhenExpands")
            
            UserDefaults.standard.setValue(true, forKey: "volumeSideButtonsEnabled")
            UserDefaults.standard.setValue(Zone.one.rawValue, forKey: "selectedZone")
        }
        
    }
    
    
    var body: some Scene {
        WindowGroup {
            ContentView()
               
        }
    }
}

func copyFileToDocuments(fileName: String, fileExtension: String) {
    let fileManager = FileManager.default
    
    // Get the URL for the file in the bundle
    guard let bundleURL = Bundle.main.url(forResource: fileName, withExtension: fileExtension) else {
        print("File \(fileName).\(fileExtension) not found in bundle.")
        return
    }
    
    // Get the URL for the Documents directory
    guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
        print("Unable to access Documents directory.")
        return
    }
    
    // Create the destination URL for the file in the Documents directory
    let destinationURL = documentsDirectory.appendingPathComponent("\(fileName).\(fileExtension)")
    
    do {
        // Check if the file already exists at the destination
        if !fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.copyItem(at: bundleURL, to: destinationURL)
            print("File copied successfully to \(destinationURL.path)")
        } else {
            print("File already exists at \(destinationURL.path)")
        }
    } catch {
        print("Error copying file: \(error)")
    }
    
}
