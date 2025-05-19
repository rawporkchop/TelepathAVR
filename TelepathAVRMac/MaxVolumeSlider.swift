//
//  MaxVolumeSlider.swift
//  TelepathAVR
//
//  Created by Oliver Larsson on 5/8/25.
//

import SwiftUI


struct MaxVolumeSlider: View {
    
    @State private var translationStartPoint: CGFloat = 0
    
    // Zone Specific Attributes
    let zone: Zone
    @State private var maxTheoreticalVolume: Double?
    @State private var cappedVolume: Double
    @State private var percentProgress: Double = 0
    
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
                                Image(systemName: "speaker.badge.exclamationmark.fill")
                                    .foregroundStyle(.black.opacity(0.7))
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
        .onAppear() {
            initialize()
        }
    }
    private func initialize() {
        
        cappedVolume = UserDefaults.standard.double(forKey: "\(zone.defaults)VolLimit")
        percentProgress = cappedVolume / (maxTheoreticalVolume ?? 98.0)
        percentProgress = min(1, max(0, percentProgress))
    }
    
    private func handleEndGesture() {
        if zone == .one {
            cappedVolume = (percentProgress * (maxTheoreticalVolume ?? 98.0) * 2).rounded() / 2
        } else {
            cappedVolume = (percentProgress * (maxTheoreticalVolume ?? 98.0)).rounded()
        }
        UserDefaults.standard.set(cappedVolume, forKey: "\(zone.defaults)VolLimit")
    }
    
    private func handleSlideGesture(_ value: DragGesture.Value, _ sliderRange: CGFloat, _ sliderStartCoord: CGFloat) {
        
        let translation = value.translation.width
        translationStartPoint = value.startLocation.x
        percentProgress = (translationStartPoint - sliderStartCoord + translation) / sliderRange
        percentProgress = min(1, max(0, percentProgress))
    }
    
    private func resetTranslations() {
        translationStartPoint = 0
    }
}
