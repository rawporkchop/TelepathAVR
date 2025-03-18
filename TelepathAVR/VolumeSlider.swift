//
//  VolumeSlider.swift
//  TelepathAVR
//
//  Created by Oliver Larsson on 1/12/25.
//


import SwiftUI


private enum Stretch {
    case up, down, neutral
}


struct VolumeSlider: View {
    
    @ObservedObject var connection: Connection = TelepathAVRApp.shared.connection
    
    private let cornerSize: CGFloat = 40
    @State private var lastSlideValue: CGFloat = 0
    private let maxStretchPercentage: CGFloat = 0.05 * 2
    @State private var stretchPercentage: CGFloat = 0
    @State private var stretchDirection: Stretch = .neutral
    @State private var inProgress: Bool = false
    @State private var hasReachedEndedValue = true
    @State private var endedVolume: Double? = nil
    @State private var hapticZoneToggleError: Bool = false
    @State private var hapticZoneToggleSuccess: Bool = false
    
    // Settings
    @State private var resizeable: Bool
    @State private var zoneTapEnabled: Bool
    @State private var allowsStretching: Bool
    
    // Theme Settings
    @State private var sliderTopColor: Color = .yellow
    @State private var sliderBaseColor: Color = .white.opacity(0.8)
    @State private var textColor: Color = .white
    
    
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
        
        resizeable = UserDefaults.standard.bool(forKey: "resizeable")
        zoneTapEnabled = UserDefaults.standard.bool(forKey: "zoneTapEnabled")
        allowsStretching = UserDefaults.standard.bool(forKey: "allowsStretching")
   }

    
    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            
            
            VStack {
                if allowsStretching {
                    if stretchDirection == .down {
                        Rectangle()
                            .frame(height: (maxStretchPercentage + stretchPercentage) / 2 * height)
                            .opacity(0)
                    }
                    else {
                        Rectangle()
                            .frame(height: (maxStretchPercentage / 2 - stretchPercentage) * height)
                            .opacity(0)
                    }
                }

                
                GeometryReader { sliderGeometry in
                    let maxHeightSlider = sliderGeometry.size.height
                    let progressHeight = maxHeightSlider * percentProgress
                    let maxWidthSlider = geometry.size.width
                    
                    
                    ZStack {
                        
                        slider(maxWidthSlider, maxHeightSlider, progressHeight)
                            .shadow(color: connection.getPowerState(zone) ? .black : .clear, radius: 25, x: 0, y: 1)
                        
                        overlay()
                            .opacity(connection.getPowerState(zone) ? 0 : 1)
                            .onTapGesture(count: 2) {
                                
                                if !connection.isConnected {
                                    hapticZoneToggleError.toggle()
                                }
                                else {
                                    hapticZoneToggleSuccess.toggle()
                                }
                                
                                if zoneTapEnabled {
                                    connection.zoneToggle(zone)
                                }
                                else {
                                    connection.powerToggle()
                                }
                            }
                    }
                }
                .overlay(
                    Image(.resizeHandle)
                    .resizable()
                    .frame(width: 30, height: 30, alignment: .bottomTrailing)
                    .opacity(0.3)
                    .visible(resizeable),
                    alignment: .bottomTrailing
                    
                )
                
                if allowsStretching {
                    if stretchDirection == .up {
                        Rectangle()
                            .frame(height: (maxStretchPercentage + stretchPercentage) / 2 * height)
                            .opacity(0)
                    }
                    else {
                        Rectangle()
                            .frame(height: (maxStretchPercentage / 2 - stretchPercentage) * height)
                            .opacity(0)
                    }
                }
            }
        }
    }
    
    func getVolumePercent(_ zone: Zone) -> Double? {
        guard let volume = volumeEndpoint, let max = connection.max else {
            return nil
        }
        
        if volume == endedVolume {
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
    
    @ViewBuilder
    func overlay() -> some View {
        // Interaction Halt
        ZStack (alignment: .topTrailing){
            Text(connection.isConnected ? "OFF" : "DISC")
                .rotationEffect(.degrees(90))
                .font(.largeTitle.bold())
                .padding(.vertical, 20)
                .offset(y: 60)
                .foregroundStyle(Color(textColor))

            Rectangle()
                .fill(.black.opacity(0.4))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .cornerRadius(cornerSize)
        }

    }
    
    @ViewBuilder
    func slider(_ maxWidthSlider: CGFloat, _ maxHeightSlider: CGFloat,_  progressHeight: CGFloat) -> some View {
        // Slider
        ZStack (alignment: .bottom) {
            // Slider Background
            Rectangle()
                .fill(sliderBaseColor)
            
            // Progress Bar
            Rectangle()
                .fill(sliderTopColor)
                .frame(height: progressHeight)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color(.black))
                        .frame(height: 3)
                        .offset(y: -3)
                        .opacity(stretchPercentage > 0 && stretchDirection == .up ? 1 : 0)
                }
                
            
            // Captions
            VStack {
                Text(zone.alias.uppercased()).font(.title2)
                Spacer()
                Text("\(String(format: "%.1f", volume))").font(.title)
            }
            .padding()
            .foregroundStyle(textColor)
            
        }
        .frame(width: maxWidthSlider * (1 - stretchPercentage), height: maxHeightSlider)
        .cornerRadius(cornerSize)
        
        .sensoryFeedback(.success, trigger: hapticZoneToggleSuccess)
        .sensoryFeedback(.error, trigger: hapticZoneToggleError)
        .sensoryFeedback(.increase, trigger: volume)
        .sensoryFeedback(.impact(weight: .heavy, intensity: 1), trigger: stretchPercentage)
        
        .onChange(of: zonePercentProgress) {
            guard let progress = zonePercentProgress else {
                return
            }
            if !inProgress && hasReachedEndedValue {
                percentProgress = progress
                rawPercentProgress = progress
                updateVolume(with: progress)
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
        .onReceive(NotificationCenter.default.publisher(for: .sliderVisibilityChanged)) { _ in
            zonePercentProgress = getVolumePercent(zone)
        }
        .onReceive(NotificationCenter.default.publisher(for: .settingsChanged)) { _ in
            getSettings()
        }
        .onReceive(NotificationCenter.default.publisher(for: .themeChanged)) { _ in
            loadColorSettings()
            print("Loading color settings")
        }
        .onAppear() {
            getSettings()
            loadColorSettings()
        }
    
    
        .highPriorityGesture(DragGesture()
            .onChanged { value in
                handleSlideGesture(value, maxHeightSlider)
            }
            .onEnded { _ in
                handleEndGesture()
            }
        )
        .simultaneousGesture(
            TapGesture(count: 2)
                .onEnded {
                    
                    hapticZoneToggleSuccess.toggle()
                    
                    if zoneTapEnabled {
                        connection.zoneToggle(zone)
                    }
                    else {
                        connection.powerToggle()
                    }
                }
        )
    }
    
    private func loadColorSettings() {
        if let settings = ColorSettings.load() {
            self.sliderBaseColor = settings.sliderBaseColor.toColor()
            self.sliderTopColor = settings.sliderTopColor.toColor()
            self.textColor = settings.textColor.toColor()
            print(sliderBaseColor)
            print(sliderTopColor)
            print(textColor)
        }
        else {
            print("Could not load color settings. Does not exist?")
        }
    }
    
    private func getSettings() {
        resizeable = UserDefaults.standard.bool(forKey: "resizeable")
        zoneTapEnabled = UserDefaults.standard.bool(forKey: "zoneTapEnabled")
        allowsStretching = UserDefaults.standard.bool(forKey: "allowsStretching")
        
        switch zone {
        case .one: cappedVolume = UserDefaults.standard.double(forKey: "zone1VolLimit")
        case .two: cappedVolume = UserDefaults.standard.double(forKey: "zone2VolLimit")
        case .three: cappedVolume = UserDefaults.standard.double(forKey: "zone3VolLimit")
        }
        
        if volume > cappedVolume {
            guard let max = maxTheoreticalVolume else { return }
            rawPercentProgress = cappedVolume / max
            updateVolume(with: rawPercentProgress)
            
        }
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
        let newVolume = (percentProgress * max * 2).rounded() / 2
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
        
        let newVolume = (percentProgress * maxVol * 2).rounded() / 2
        endedVolume = newVolume
        
        guard let progress = zonePercentProgress else {
            return
        }
        let zoneVolume = (progress * maxVol * 2).rounded() / 2
        if zoneVolume == endedVolume {
            hasReachedEndedValue = true
        }
    }
    
    
    private func handleSlideGesture(_ value: DragGesture.Value, _ maxHeightSlider: CGFloat) {
        
        print("Slide Gesture")
        inProgress = true
        endedVolume = nil
        hasReachedEndedValue = false
        
        guard let maxVol = maxTheoreticalVolume else {
            return
        }
        guard zonePercentProgress != nil else {
            return
        }
        
        let translation = -value.translation.height
        rawPercentProgress += (translation - lastSlideValue) / maxHeightSlider
        lastSlideValue = translation
                
        
        //Stretchy Slider Implementation
        
        let effectivePercentLimit = cappedVolume / maxVol
        
        if rawPercentProgress >= effectivePercentLimit && allowsStretching {
            stretchDirection = .up
            modifyStretchPercentage(using: rawPercentProgress-effectivePercentLimit)
        }
        else if rawPercentProgress <= 0 && allowsStretching {
            stretchDirection = .down
            modifyStretchPercentage(using: abs(rawPercentProgress))
        }
        else {
            stretchDirection = .neutral
            stretchPercentage = 0
        }
        updateVolume(with: max(0, min(rawPercentProgress, effectivePercentLimit)))
    }
    
    
    private func modifyStretchPercentage(using overshoot: Double) {
        let sensitivity = 0.125
        stretchPercentage = max(0, min(overshoot * sensitivity, maxStretchPercentage / 2))
    }
    
    
    private func resetTranslations() {
        lastSlideValue = 0
        rawPercentProgress = percentProgress
        stretchDirection = .neutral
        stretchPercentage = 0
    }
    

}
extension Notification.Name {
    static let sliderVisibilityChanged = Notification.Name("sliderVisibilityChanged")
}

#Preview {
    ContentView()
}
