//
//  AudioSession.swift
//  Telepath
//
//  Created by Oliver Larsson on 7/20/24.
//

import AVFoundation
import MediaPlayer
import SwiftUI

public class AudioSession: NSObject {
    static let shared = AudioSession()
    @StateObject private var connection = TelepathAVRApp.shared.connection
    private var sideVolButtonsEnabled: Bool = false
    private var audioLevel: Float = 0.5
    private var filename: String?
    private var player: AVAudioPlayer?
    private var sessionActive: Bool = false
    private var skipNext: Bool = false
    
    private var maxVolume: CGFloat?
    private var minVolume: CGFloat?
    private var activeZone: Zone = .one 
    let volumeView = MPVolumeView(frame: .zero)
    
    private var audioSession = AVAudioSession.sharedInstance()
    
    private override init() {
        super.init()
        volumeView.showsVolumeSlider = false
        do {
            try audioSession.setCategory(.playback, mode: .default)
            audioSession.addObserver(self, forKeyPath: "outputVolume", options: NSKeyValueObservingOptions.new, context: nil)
        } catch {
            print("Failed to set the audio session configuration: \(error.localizedDescription)")
        }
    }
    
    public func setActive() {
        sideVolButtonsEnabled = UserDefaults.standard.bool(forKey: "volumeSideButtonsEnabled")
        minVolume = 0
        activeZone = getActiveZone()
        maxVolume = getMaxVolume()
        
        if !sideVolButtonsEnabled {
            print("Audio session disabled")
            return
        }
        
        do {
            try audioSession.setActive(true)
            sessionActive = true
            startSilenceLoop()
            
            print("Audio session activated")
        } catch {
            print("Failed to start audio session: \(error.localizedDescription)")
        }
    }
    
    private func getActiveZone() -> Zone {

        return Zone(rawValue: UserDefaults.standard.string(forKey: "selectedZone") ?? Zone.one.rawValue) ?? .one
    }
    
    private func getMaxVolume() -> CGFloat {
        let zone = getActiveZone()
        let defaults = UserDefaults.standard
        switch zone {
        case .one: return CGFloat(defaults.double(forKey: "zone1VolLimit"))
        case .two: return CGFloat(defaults.double(forKey: "zone2VolLimit"))
        case .three: return CGFloat(defaults.double(forKey: "zone3VolLimit"))
        }
    }
    
    public func setInactive() {
        do {
            try audioSession.setActive(false)
            sessionActive = false
            print("Audio session disabled")
        } catch {
            print("Failed to stop audio session: \(error.localizedDescription)")
        }
    }
    
    public func setSystemVolume(volume: CGFloat) {
        
        guard let minVolume = minVolume, let maxVolume = maxVolume else {
            print("Min volume and/or max volume not initialized")
            return
        }
        
        var systemVolume = Float((volume - minVolume) / (maxVolume - minVolume))
        systemVolume = max(systemVolume, 0)
        
        skipNext = true
        MPVolumeView.setVolume(systemVolume)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.skipNext = false
        }
    }
    
    private func startSilenceLoop() {
        DispatchQueue.global(qos: .background).async {
            let url = Bundle.main.url(forResource: "silence", withExtension: "wav")
            guard let url = url else {
                return
            }
            
            while self.sessionActive {
                do {
                    let player = try AVAudioPlayer(contentsOf: url)
                    player.play()
                    Thread.sleep(forTimeInterval: 55.0)
                } catch {
                    print("Something went wrong: \(error)")
                }
            }
        }
    }
    
    public func isBackgroundAudioPlaying() -> Bool {
        return audioSession.isOtherAudioPlaying
    }
    
    private func enqueueVolumeSide(systemVolume: Float) {
        guard let minVolume = minVolume, let maxVolume = maxVolume else {
            print("minVolume or maxVolume not initialized")
            return
        }
        
        if minVolume >= maxVolume {
            print("minVolume >= maxVolume")
            return
        }
        
        var volume = CGFloat(systemVolume)*(maxVolume - minVolume) + minVolume
        volume = max(minVolume, min(volume, maxVolume))
        activeZone = getActiveZone()
        let changedVolume = activeZone == .one ? (volume * 2).rounded() / 2 : volume.rounded()
        

        connection.enqueueVolume(changedVolume, activeZone)
    }
    
    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "outputVolume" {
            if skipNext == true {
                return
            }
            let audioSession = AVAudioSession.sharedInstance()
            if audioSession.outputVolume != audioLevel {
                enqueueVolumeSide(systemVolume: audioSession.outputVolume)
            }
            audioLevel = audioSession.outputVolume
        }
    }
    
    deinit {
        audioSession.removeObserver(self, forKeyPath: "outputVolume")
    }
}

extension MPVolumeView {
    static func setVolume(_ volume: Float) {
        let volumeView = MPVolumeView()
        let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            slider?.value = volume
        }
    }
}
struct VolumeViewModifier: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            VolumeView()
                .frame(width: 0, height: 0)
            content
        }
    }
    
    struct VolumeView: UIViewRepresentable{
        func makeUIView(context: Context) -> MPVolumeView {
           let volumeView = MPVolumeView(frame: CGRect.zero)
           volumeView.alpha = 0.001
           return volumeView
        }
        func updateUIView(_ uiView: MPVolumeView, context: Context) { }
    }
}

public func getVolume(_ zone: Zone) -> CGFloat? {
    switch zone {
    case .one: return CGFloat(TelepathAVRApp.shared.connection.z1?.volume ?? 0)
    case .two: return CGFloat(TelepathAVRApp.shared.connection.z2?.volume ?? 0)
    case .three: return CGFloat(TelepathAVRApp.shared.connection.z3?.volume ?? 0)
    }
}
