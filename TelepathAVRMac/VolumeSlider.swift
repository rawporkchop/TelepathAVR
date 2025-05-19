//
//  VolumeSlider.swift
//  TelepathAVR
//
//  Created by Oliver Larsson on 4/29/25.
//

import SwiftUI


struct VolumeSlider: View {
    
    @ObservedObject var connection: Connection = TelepathAVRMacApp.shared.connection

    @State private var translationStartPoint: CGFloat = 0
    @State private var inProgress: Bool = false
    @State private var hasReachedEndedValue = true
    @State private var endedVolume: Double? = nil
    
    // Zone Specific Attributes
    let zone: Zone
    @State private var maxTheoreticalVolume: Double?
    @State private var cappedVolume: Double
    @State var volume: Double = 0
    @State private var zonePercentProgress: Double?
    @State private var percentProgress: Double = 0
    @State private var rawPercentProgress: Double = 0
    var volumeEndpoint: Double? {
        switch zone {
        case .one: return connection.z1?.volume
        case .two: return connection.z2?.volume
        case .three: return connection.z3?.volume
        }
    }
    
    
    init(zone: Zone) {
        self.zone = zone
        
        switch zone {
        case .one: cappedVolume = UserDefaults.standard.double(forKey: "zone1VolLimit")
        case .two: cappedVolume = UserDefaults.standard.double(forKey: "zone2VolLimit")
        case .three: cappedVolume = UserDefaults.standard.double(forKey: "zone3VolLimit")
            
        }
   }
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            let sliderRange = width - height
            let progressWidth = sliderRange * percentProgress
            let sliderStartCoord = geometry.frame(in: .global).minX - height
            
            ZStack {
                Capsule()
                    .fill(.white)
                    .frame(width: width, height: height)
                    .opacity(0.2)
                HStack {
                    Capsule()
                        .frame(width: progressWidth + height, height: height)
                        .overlay(alignment: .trailing) {
                            Circle()
                                .frame(width: height, height: height)
                                .shadow(color: .gray, radius: 1)
                                .opacity(percentProgress > 0.2 ? 1 : percentProgress * 5)
                        }
                        .overlay(alignment: .leading) {
                            Group {
                                if percentProgress == 0 {
                                    Image(systemName: "speaker.slash.fill")
                                        .foregroundStyle(.black.opacity(0.7))
                                }
                                else if percentProgress < 0.3 {
                                    Image(systemName: "speaker.wave.1.fill")
                                        .foregroundStyle(.black.opacity(0.7))
                                }
                                else if percentProgress < 0.6 {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .foregroundStyle(.black.opacity(0.7))
                                }
                                else {
                                    Image(systemName: "speaker.wave.3.fill")
                                        .foregroundStyle(.black.opacity(0.7))
                                }
                            }
                            .padding(.leading, 2)
                        }
                    
                    Spacer(minLength: 0)
                }
            }
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { value in
                    handleSlideGesture(value, sliderRange, sliderStartCoord)
                }
                .onEnded { _ in
                    handleEndGesture()
                }
            )
        }
        .onChange(of: zonePercentProgress) {
            guard let progress = zonePercentProgress else {
                return
            }
            if !inProgress && hasReachedEndedValue {
                percentProgress = progress
                rawPercentProgress = progress
                updateVolume(with: progress)
                print("updating volume")
            }
        }
        .onChange(of: connection.isConnected) {
            if !connection.isConnected {
                volume = 0
                percentProgress = 0
                rawPercentProgress = 0
                zonePercentProgress = 0
            }
            print("Changed connection")
            zonePercentProgress = getVolumePercent(zone)
        }
        .onChange(of: volumeEndpoint) {
            zonePercentProgress = getVolumePercent(zone)
        }
        .onChange(of: connection.max) {
            setMax(connection.max)
            zonePercentProgress = getVolumePercent(zone)
        }
        .onAppear() {
            initialize()
        }
    }
    private func initialize() {
        
        print("initializing")
        cappedVolume = UserDefaults.standard.double(forKey: "\(zone.defaults)VolLimit")
        if getVolumePercent(zone) ?? 0.0 <= (cappedVolume / (maxTheoreticalVolume ?? 98.0)) {
            zonePercentProgress = getVolumePercent(zone)
        } else {
            zonePercentProgress = cappedVolume / (maxTheoreticalVolume ?? 98.0)
            connection.enqueueVolume(cappedVolume, zone)
        }
        
        let max = maxTheoreticalVolume ?? 98.0
        if volume > cappedVolume {
            rawPercentProgress = cappedVolume / max
            updateVolume(with: rawPercentProgress)
            print(volume)
        }
    }
    
    func getVolumePercent(_ zone: Zone) -> Double? {
        guard let volume = volumeEndpoint, let max = connection.max else {
            return nil
        }
        
        if volume == endedVolume && !inProgress{
            hasReachedEndedValue = true
        }
        setMax(max)
        return volume / max

    }
    
    func setMax(_ max: Double?) {
        guard let max = max else {
            return
        }
        maxTheoreticalVolume = max
    }
    
    private func updateVolume(with rawPercentProgress: Double) {
        guard let max = maxTheoreticalVolume else {
            print("Max Volume not Initialized")
            return
        }
        guard zonePercentProgress != nil else {
            print("Zone Volume not Initialized")

            return
        }
        percentProgress = rawPercentProgress
        let newVolume = zone == .one ? (percentProgress * max * 2).rounded() / 2 : (percentProgress * max).rounded()
        if newVolume != volume {
            volume = newVolume
            if inProgress {
                connection.enqueueVolume(volume, zone)
            }
        }
    }
    
    
    private func handleEndGesture() {
        print("Ended Gesture")
        guard let maxVol = maxTheoreticalVolume else {
            return
        }
        guard zonePercentProgress != nil else {
            return
        }
        
        let effectivePercentLimit = volume / cappedVolume
        
        withAnimation(.snappy(duration: 0.3, extraBounce: 0.4)) {
            resetTranslations()
        }
        updateVolume(with: max(0, min(rawPercentProgress, effectivePercentLimit)))
        inProgress = false
        
        let newVolume = zone == .one ? (percentProgress * maxVol * 2).rounded() / 2 : (percentProgress * maxVol).rounded()
        endedVolume = newVolume
        
        guard let progress = zonePercentProgress else {
            return
        }
        let zoneVolume = zone == .one ? (progress * maxVol * 2).rounded() / 2 : (progress * maxVol).rounded()
        if zoneVolume == endedVolume {
            hasReachedEndedValue = true
        }
    }
    
    
    private func handleSlideGesture(_ value: DragGesture.Value, _ sliderRange: CGFloat, _ sliderStartCoord: CGFloat) {
        
        if !inProgress {
            print("Slide Gesture")
            inProgress = true
            endedVolume = nil
            hasReachedEndedValue = false
        }

        guard let maxVol = maxTheoreticalVolume else {
            return
        }
        guard zonePercentProgress != nil else {
            return
        }
        
        let translation = value.translation.width
        translationStartPoint = value.startLocation.x
        rawPercentProgress = (translationStartPoint - sliderStartCoord + translation) / sliderRange
        
        let effectivePercentLimit = cappedVolume / maxVol
        updateVolume(with: max(0, min(rawPercentProgress, effectivePercentLimit)))
    }
    
    private func resetTranslations() {
        translationStartPoint = 0
        rawPercentProgress = percentProgress
    }
    
}
