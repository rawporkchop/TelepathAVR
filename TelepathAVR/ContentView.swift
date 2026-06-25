//
//  ContentView.swift
//  TelepathAVR
//
//  Created by Oliver Larsson on 1/12/25.
//

import SwiftUI

/// Visible/reserve zone sets as a **reference type**, read live every frame by the content closure
/// inside `AnimatedSideBar`'s display clock. On iOS 26 the drawer's `body` is never re-invoked when
/// its inputs change (see `DrawerController`), so a zone change made through `@State` never reaches
/// the captured content closure. Holding the sets on a stable reference lets the closure read the
/// current `showing` every frame, so a `ForEach` over it can add/remove a slider **within the
/// existing container** — animating the insert/removal with a slide transition — instead of re-`id`-ing
/// (and rebuilding) the whole `AnimatedSideBar`.
final class ZoneController: ObservableObject {
    @Published var showing: [Zone]
    @Published var reserve: [Zone]

    init(showing: [Zone] = [.one], reserve: [Zone] = [.two, .three]) {
        self.showing = showing
        self.reserve = reserve
    }

    /// Reveal the next reserved zone (right-to-left swipe). Returns whether anything changed.
    @discardableResult
    func add() -> Bool {
        guard let next = reserve.first else { return false }
        showing.append(next)
        reserve.removeFirst()
        return true
    }

    /// Hide the last visible zone (left-to-right swipe). At least one slider always stays shown, so
    /// Main (.one) is never removed. Returns whether anything changed.
    @discardableResult
    func remove() -> Bool {
        guard showing.count > 1, let last = showing.last else { return false }
        reserve.insert(last, at: 0)
        showing.removeLast()
        return true
    }
}

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
    @StateObject private var drawer = DrawerController()

    // Zones — held on a reference type so the content closure can read the live `showing` set every
    // frame (see ZoneController); `@State` here would be snapshotted into the stale captured closure.
    @StateObject private var zones = ZoneController()
    @State private var zoneWidths: CGFloat = 130
    @State private var zoneHeightsOffset: CGFloat = 0
    @State private var lastXDragValue: CGFloat = 0
    @State private var lastYDragValue: CGFloat = 0
    @State private var isResizing: Bool = false
    @State private var screenSize: CGSize = UIScreen.main.bounds.size
    
    // Tutorial
    @AppStorage("showingAlert") private var showingAlert = true

    var body: some View {
        let height = screenSize.height + zoneHeightsOffset

        return AnimatedSideBar(
                rotatesWhenExpands: $rotatesWhenExpands,
                disablesInteraction: true,
                sideMenuWidth: 200,
                cornerRadius: 25,
                drawer: drawer
            ) { safeArea in
                NavigationStack {
                    ZStack {
                        RadialGradient(
                            gradient: Gradient(colors: gradientColors),
                            center: .center,
                            startRadius: 5,
                            endRadius: 500
                        )
                        .scaleEffect(2)

                        // Volume Sliders — driven by the live `zones.showing` set so a swipe
                        // adds/removes a slider in THIS HStack (each slides in/out from the trailing
                        // edge via the resizableSlider's `.transition`), rather than rebuilding the
                        // whole container. The slide is driven by `.animation(value:)` (NOT a
                        // `withAnimation` at the mutation site): the content re-renders every frame
                        // inside AnimatedSideBar's display clock, so the modifier catches the
                        // `showing` change at render time and animates the ForEach transition — a
                        // `withAnimation` transaction would not reach this nested, clock-driven diff.
                        HStack {
                            ForEach(zones.showing) { zone in
                                resizableSlider(zone: zone, size: screenSize, height: height)
                            }
                        }
                        .animation(.snappy(duration: 0.5, extraBounce: 0.15), value: zones.showing)

                        // The menu opens with a left-to-right edge swipe, so the leading toolbar
                        // only carries the demo indicator now.
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Text("Demo")
                                    .visible(connection.isDemoActive)
                                    .font(.title3)
                                    .foregroundStyle(.white)
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
            // The drawer animates open/close smoothly via its own display-clock driver, so `isOpen`
            // is intentionally NOT in this `.id`. The Theme sub-page IS reactive content the drawer
            // can't otherwise refresh on iOS 26 (AnimatedSideBar.body is never re-invoked), so re-`id`
            // on `showThemeView` to rebuild it in/out. The zone set is NOT in the `.id` — it lives on
            // the `zones` reference read live by the content closure, so adding/removing a slider
            // updates this same container (and slides) without a rebuild.
            .id(showThemeView)
            .onAppear {
                initializeApp()
            }
            .task {
                guard UserDefaults.standard.bool(forKey: "animTest") else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                    withAnimation(.easeInOut(duration: 1.2)) { drawer.isOpen.toggle() }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .settingsChanged)) { _ in
                getSettings()
            }
            .onReceive(NotificationCenter.default.publisher(for: .themeChanged)) { _ in
                loadColorSettings()
            }
            .sheet(isPresented: $showReceiversSheet) { ReceiversView().environmentObject(connection) }
            .sheet(isPresented: $showAboutSheet) { AboutView() }
            .sheet(isPresented: $showGeneralView) { GeneralView() }
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { screenSize = geo.size }
                        .onChange(of: geo.size) { screenSize = geo.size }
                }
            )
        .alert("Proceed to connect to an audio receiver?", isPresented: $showingAlert) {
            Button("Continue") {
                drawer.isOpen = true
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
        guard value.startLocation.x > 50, !drawer.isOpen, !isResizing, zonesEnabled, !showGeneralView else { return }
        
        let xTranslation = value.translation.width
        // The slide is animated by `.animation(value: zones.showing)` on the slider HStack, not here:
        // a `withAnimation` transaction does not reach the clock-driven content diff (it snaps).
        if xTranslation < -100 {
            addZoneToShow()
        } else if xTranslation > 100 {
            removeZoneFromShow()
        }
    }
    
    private func addZoneToShow() {
        guard zones.add() else { return }
        notifySliderVisibilityChanged()
    }

    private func removeZoneFromShow() {
        guard zones.remove() else { return }
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
    
    func resizableSlider(zone: Zone, size: CGSize, height: CGFloat) -> some View {
        VolumeSlider(zone: zone)
            .frame(maxWidth: zoneWidths, maxHeight: height)
            .overlay(
                Rectangle()
                    .fill(Color.white.opacity(0.001))
                    .offset(y: allowsStretching ? -0.05 * height : 0)
                    .frame(width: 40, height: 40)
                    .highPriorityGesture(DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            handleSliderResize(value, size: size)
                        }
                        .onEnded { _ in
                            resetResizing()
                        }), alignment: .bottomTrailing
            )
            // The slider is conditionally present via the `ForEach(zones.showing)`, so a swipe that
            // adds/removes its zone slides it fully in from / out past the right screen edge. Offset
            // by a whole screen width (not `.move(edge:)`, which only travels the slider's own width)
            // so it clears the screen completely regardless of its resting position.
            .transition(.offset(x: size.width))
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
    
    private func handleSliderResize(_ value: DragGesture.Value, size: CGSize) {
        guard resizeable else { return }
        isResizing = true
        let xTranslation = value.translation.width - lastXDragValue
        zoneWidths += xTranslation
        zoneWidths = max(120, min(size.width, zoneWidths))
        lastXDragValue = value.translation.width

        let yTranslation = value.translation.height - lastYDragValue
        zoneHeightsOffset += yTranslation
        zoneHeightsOffset = max(-size.height / 2, min(0, zoneHeightsOffset))
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

