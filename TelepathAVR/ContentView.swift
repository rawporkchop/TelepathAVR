//
//  ContentView.swift
//  TelepathAVR
//
//  Created by Oliver Larsson on 1/12/25.
//

import SwiftUI

struct ContentView: View {

    // Receiver
    @ObservedObject private var connection: Connection = TelepathAVRApp.shared.connection
    @StateObject private var selectedReceiver = TelepathAVRApp.shared.selectedReceiver
    
    // Settings
    @State private var zonesEnabled: Bool = true
    @State private var resizeable: Bool = true
    @State private var rotatesWhenExpands: Bool = true
    @State private var allowsStretching: Bool = true
    @State private var gradientColors: [Color] = [.gray, .black]
    @State private var volumeSideButtonsEnabled = true

    
    // Views & Navigation
    @State private var showReceiversSheet = false
    @State private var showGeneralView = false
    @State private var showThemeView = false
    @State private var showAboutSheet = false
    @State private var showMenu: Bool = false
    
    // Zones
    @State private var zonesShowing: [Zone] = [.one]
    @State private var zonesInReserve: [Zone] = [.two, .three]
    @State private var zoneWidths: CGFloat = 130
    @State private var zoneHeightsOffset: CGFloat = 0
    @State private var lastXDragValue: CGFloat = 0
    @State private var lastYDragValue: CGFloat = 0
    @State private var isResizing: Bool = false
    
    // Tutorial
    @AppStorage("showingAlert") private var showingAlert = true
    
    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height + zoneHeightsOffset
            let width = geometry.size.width
            
            AnimatedSideBar(
                rotatesWhenExpands: $rotatesWhenExpands,
                disablesInteraction: true,
                sideMenuWidth: 200,
                cornerRadius: 25,
                showMenu: $showMenu
            ) { safeArea in
                NavigationStack {
                    NavigationLink(destination: GeneralView(), isActive: $showGeneralView) { EmptyView() }
                    
                    ZStack {
                        RadialGradient(
                            gradient: Gradient(colors: gradientColors),
                            center: .center,
                            startRadius: 5,
                            endRadius: 500
                        )
                        .scaleEffect(2)
                        
                        // Volume Sliders
                        HStack {
                            resizableSlider(zone: .one, geometry: geometry, height: height, width: width)
                            resizableSlider(zone: .two, geometry: geometry, height: height, width: width)
                            resizableSlider(zone: .three, geometry: geometry, height: height, width: width)
                        }
                        
                        // Tool Bar Button
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                HStack {
                                    Button(action: { showMenu.toggle() }) {
                                        Image(systemName: showMenu ? "xmark" : "line.3.horizontal")
                                            .foregroundStyle(.white)
                                            .contentTransition(.symbolEffect)
                                    }
                                    Text("Demo")
                                        .visible(connection.isDemoActive)
                                        .font(.title3)
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                    }
                }
            } menuView: { safeArea in
                SideBarMenuView(safeArea)
                
                if showThemeView {
                    ThemeView(safeArea)
                        .transition(.move(edge: .leading))
                        .zIndex(1)
                }
            } background: {
                Rectangle().fill(.sideMenu)
            }
            .onAppear {
                initializeApp()
            }
            .onReceive(NotificationCenter.default.publisher(for: .settingsChanged)) { _ in
                getSettings()
            }
            .onReceive(NotificationCenter.default.publisher(for: .themeChanged)) { _ in
                loadColorSettings()
            }
            .sheet(isPresented: $showReceiversSheet) { ReceiversView().environmentObject(connection) }
            .sheet(isPresented: $showAboutSheet) { AboutView() }
        }
        .alert("Proceed to connect to an audio receiver?", isPresented: $showingAlert) {
            Button("Continue") {
                showMenu = true
                showReceiversSheet = true
            }
            Button("No") {
                showingAlert = false
            }
        }
        .hideVolumeHUD()
        .simultaneousGesture(DragGesture().onEnded(handleDragGesture))
    }
    
    private func initializeApp() {
        guard !connection.isConnected else { return }
        connection.start(receiver: selectedReceiver.receiver)
        print("Starting connection")
        getSettings()
        loadColorSettings()
        
    }
    
    private func handleDragGesture(_ value: DragGesture.Value) {
        guard value.startLocation.x > 50, !showMenu, !isResizing, zonesEnabled, !showGeneralView else { return }
        
        let xTranslation = value.translation.width
        withAnimation(.snappy(duration: 0.5, extraBounce: 0.15)) {
            if xTranslation < -100 {
                addZoneToShow()
            } else if xTranslation > 100 {
                removeZoneFromShow()
            }
        }
    }
    
    private func addZoneToShow() {
        guard let addedZone = zonesInReserve.first else { return }
        zonesShowing.append(addedZone)
        zonesInReserve.removeFirst()
        notifySliderVisibilityChanged()
    }
    
    private func removeZoneFromShow() {
        guard let removedZone = zonesShowing.last else { return }
        zonesInReserve.insert(removedZone, at: 0)
        zonesShowing.removeLast()
        notifySliderVisibilityChanged()
    }
    
    private func notifySliderVisibilityChanged() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            NotificationCenter.default.post(name: .sliderVisibilityChanged, object: nil)
        }
    }
    
    private func getSettings() {
        zonesEnabled = UserDefaults.standard.bool(forKey: "zonesEnabled")
        resizeable = UserDefaults.standard.bool(forKey: "resizeable")
        rotatesWhenExpands = UserDefaults.standard.bool(forKey: "rotatesWhenExpands")
        allowsStretching = UserDefaults.standard.bool(forKey: "allowsStretching")
        volumeSideButtonsEnabled = UserDefaults.standard.bool(forKey: "volumeSideButtonsEnabled")
        if volumeSideButtonsEnabled &&
            TelepathAVRApp.shared.audioSession.isBackgroundAudioPlaying()
            == false
        {
            TelepathAVRApp.shared.audioSession.setActive()
        }
        else {
            TelepathAVRApp.shared.audioSession.setInactive()
        }
    }
    
    private func loadColorSettings() {
        if let settings = ColorSettings.load() {
            gradientColors = settings.gradientColors.map { $0.toColor() }
        } else {
            print("Could not find color settings")
        }
    }
    
    func shutDown() {
        connection.stop()
        print("Stopping connection")
    }
    
    @ViewBuilder
    func SideBarMenuView(_ safeArea: UIEdgeInsets) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings").font(.largeTitle.bold())
            SideBarButton(.general) { showGeneralView.toggle() }
            SideBarButton(.theme) { withAnimation { showThemeView.toggle() } }
            SideBarButton(.receivers) { showReceiversSheet.toggle() }
            Spacer()
            SideBarButton(.about) { showAboutSheet.toggle() }
        }
        .padding([.horizontal, .vertical], 15)
        .padding(.top, safeArea.top)
        .padding(.bottom, safeArea.bottom)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .environment(\.colorScheme, .dark)
    }
    
    @ViewBuilder
    func ThemeView(_ safeArea: UIEdgeInsets) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation { showThemeView.toggle() }
            } label: {
                HStack {
                    Image(systemName: "chevron.left").font(.title)
                    Text("Theme").font(.largeTitle.bold()).foregroundStyle(.white)
                }
            }
            presetsList()
        }
        .background(.sideMenu)
        .padding([.horizontal, .vertical], 15)
        .padding(.top, safeArea.top)
        .padding(.bottom, safeArea.bottom)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .environment(\.colorScheme, .dark)
        .transition(.move(edge: .leading))
        .animation(.easeInOut(duration: 0.5), value: showThemeView)
    }
    
    @ViewBuilder
    func SideBarButton(_ tab: Tab, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: tab.rawValue).font(.title3)
                Text(tab.title).font(.callout)
                Spacer()
            }
            .padding(.vertical, 10)
            .contentShape(.rect)
            .foregroundStyle(Color.primary)
        }
    }
    
    func resizableSlider(zone: Zone, geometry: GeometryProxy, height: CGFloat, width: CGFloat) -> some View {
        VolumeSlider(zone: zone)
            .frame(maxWidth: zoneWidths, maxHeight: height)
            .offset(x: zonesShowing.contains(zone) ? 0 : width)
            .transition(.move(edge: .trailing))
            .visible(zonesShowing.contains(zone))
            .overlay(
                Rectangle()
                    .fill(Color.white.opacity(0.001))
                    .offset(y: allowsStretching ? -0.05 * height : 0)
                    .frame(width: 40, height: 40)
                    .highPriorityGesture(DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            handleSliderResize(value, geometry: geometry)
                        }
                        .onEnded { _ in
                            resetResizing()
                        }), alignment: .bottomTrailing
            )
    }
    
    func AboutView() -> some View {
        ScrollView {
            LazyVStack {
                Text("Hey I'm Oliver! I'm a Solo Dev.")
                    .font(.headline)
                Text("\tWhen I published this app, I was a High School Student; this iOS app was a summer project. Since I published this app for free, it would mean the world to me if you shared it with your friends. If you would like to contact me, there is information below:")
                    .padding()
                    .multilineTextAlignment(.leading)
            }
            .padding(.vertical, 40)
            .frame(maxWidth: 500)
        }
    }
    
    private func handleSliderResize(_ value: DragGesture.Value, geometry: GeometryProxy) {
        guard resizeable else { return }
        isResizing = true
        let xTranslation = value.translation.width - lastXDragValue
        zoneWidths += xTranslation
        zoneWidths = max(120, min(geometry.size.width, zoneWidths))
        lastXDragValue = value.translation.width
        
        let yTranslation = value.translation.height - lastYDragValue
        zoneHeightsOffset += yTranslation
        zoneHeightsOffset = max(-geometry.size.height / 2, min(0, zoneHeightsOffset))
        lastYDragValue = value.translation.height
    }
    
    private func resetResizing() {
        lastXDragValue = 0
        lastYDragValue = 0
        isResizing = false
    }

    enum Tab: String, CaseIterable {
        case general = "gear"
        case theme = "wand.and.stars"
        case receivers = "wave.3.forward"
        case about = "person.fill"
        
        var title: String {
            switch self {
            case .general: return "General"
            case .theme: return "Theme"
            case .receivers: return "Receivers"
            case .about: return "About"
            }
        }
    }
}

public extension View {
    func visible(_ isVisible: Bool) -> some View {
        modifier(VisibleModifier(isVisible: isVisible))
    }
    func hideVolumeHUD() -> some View {
        modifier(VolumeViewModifier())
    }
}

fileprivate struct VisibleModifier: ViewModifier {
    let isVisible: Bool
    func body(content: Content) -> some View {
        Group {
            if isVisible {
                content
            } else {
                EmptyView()
            }
        }
    }
}

#Preview {
    ContentView()
}

