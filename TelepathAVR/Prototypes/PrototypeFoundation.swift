//
//  PrototypeFoundation.swift
//  TelepathAVR — Side-menu open / close animation prototypes
//
//  A self-contained gallery for trying out several "show / hide the side menu"
//  animations, with the emphasis on REALISTIC 3D rotation of the content.
//
//  WHY THIS LIVES APART FROM AnimatedSideBar
//  -----------------------------------------
//  The shipping `AnimatedSideBar` can only refresh via an `.id(...)` identity swap
//  on iOS 26 (see that file's header note), which makes its open/close transition an
//  instant SNAP — there are no in-between frames to interpolate, so it can never look
//  "realistic". This gallery sidesteps the whole question: it drives the animation
//  from a `TimelineView(.animation)` display clock, computing `progress` analytically
//  every frame. The DRIVER produces the in-between frames, not a `Bool` state change,
//  so the visuals interpolate smoothly REGARDLESS of SwiftUI's invalidation behaviour.
//
//  Open the `#Preview` at the bottom in Xcode, or launch the app with
//  `-prototypeCapture YES` to run the capture gallery full-screen on device/sim.
//

import SwiftUI

// MARK: - Style contract

/// Everything a style needs to lay out the drawer + content for one frame.
struct DrawerGeometry {
    var menuWidth: CGFloat
    var size: CGSize
    var safeArea: EdgeInsets
}

/// A pluggable open/close animation. `scene` composes the full screen for a given
/// `progress` (0 = closed, 1 = open). `progress` may briefly overshoot just past 1
/// or just below 0 when a style opts into a springy ease — styles should tolerate that.
///
/// Add a new style by writing `extension DrawerStyle { static var foo: DrawerStyle { … } }`
/// in its own file and listing it in `DrawerStyleRegistry.all`.
struct DrawerStyle: Identifiable {
    let id: String
    let name: String
    let blurb: String
    let scene: (_ progress: CGFloat, _ geo: DrawerGeometry, _ content: AnyView, _ menu: AnyView) -> AnyView

    init(id: String,
         name: String,
         blurb: String,
         scene: @escaping (_ progress: CGFloat, _ geo: DrawerGeometry, _ content: AnyView, _ menu: AnyView) -> AnyView) {
        self.id = id
        self.name = name
        self.blurb = blurb
        self.scene = scene
    }
}

// MARK: - Math helpers (shared by every style)

@inline(__always) func clamp01(_ x: CGFloat) -> CGFloat { min(max(x, 0), 1) }
@inline(__always) func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }

/// Ease with a small overshoot near the end — reads as a light spring settle.
/// Good for rotations, where a touch of overshoot feels physical.
func easeOutBack(_ t: CGFloat) -> CGFloat {
    let c1: CGFloat = 1.70158
    let c3 = c1 + 1
    let u = t - 1
    return 1 + c3 * u * u * u + c1 * u * u
}

/// Smooth, no-overshoot ease for styles where overshoot would look wrong.
func easeInOutCubic(_ t: CGFloat) -> CGFloat {
    t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
}

// MARK: - The gallery

/// Drives `progress` from a display-frame clock and hands it to the selected style.
/// Interactions: the **Open / Close** button, ◀ ▶ to switch styles, and an edge-drag.
/// `autoLoop` opens/closes on a timer (used by the screenshot capture pass).
struct PrototypeGallery: View {
    var styles: [DrawerStyle] = DrawerStyleRegistry.all
    var autoLoop: Bool = false
    var autoAdvanceStyles: Bool = false

    private let menuWidth: CGFloat = 280
    private let duration: Double = 0.62

    @State private var styleIndex = 0
    @State private var open = false

    // Analytic animation snapshot — captured whenever the target changes. Reading these
    // every frame inside the TimelineView (instead of writing @State during render) keeps
    // the interpolation independent of SwiftUI's normal invalidation path.
    @State private var animFrom: CGFloat = 0
    @State private var animTo: CGFloat = 0
    @State private var animStart: Date = .distantPast

    // Live finger drag.
    @GestureState private var dragX: CGFloat = 0
    @State private var dragging = false

    private var style: DrawerStyle {
        styles.isEmpty ? .placeholder : styles[min(styleIndex, styles.count - 1)]
    }

    var body: some View {
        GeometryReader { proxy in
            let geo = DrawerGeometry(menuWidth: menuWidth,
                                     size: proxy.size,
                                     safeArea: proxy.safeAreaInsets)
            ZStack {
                // The animated scene. TimelineView(.animation) re-renders every display
                // frame, so `progress(at:)` is sampled continuously — the source of the
                // smooth motion that a `Bool`-driven body could not provide here.
                TimelineView(.animation) { tl in
                    style.scene(progress(at: tl.date),
                                geo,
                                AnyView(DemoContent()),
                                AnyView(DemoMenu(safeArea: proxy.safeAreaInsets)))
                }

                controls
            }
            .contentShape(Rectangle())
            .gesture(drag(geo: geo))
            .ignoresSafeArea()
            .task(id: autoLoop) {
                guard autoLoop else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_700_000_000)
                    animate(to: !open, from: open ? 1 : 0)
                }
            }
            .task(id: autoAdvanceStyles) {
                guard autoAdvanceStyles else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 4_300_000_000)
                    styleIndex = (styleIndex + 1) % max(styles.count, 1)
                }
            }
        }
    }

    // MARK: Progress

    /// Resting progress for the current open state.
    private var resting: CGFloat { open ? 1 : 0 }

    /// The progress to show at `now`: follow the finger while dragging, otherwise play
    /// the eased animation from the last snapshot.
    private func progress(at now: Date) -> CGFloat {
        if dragging {
            return clamp01(resting + dragX / menuWidth)
        }
        let elapsed = now.timeIntervalSince(animStart)
        if elapsed >= duration { return animTo }
        let t = CGFloat(elapsed / duration)
        return animFrom + (animTo - animFrom) * easeOutBack(t)
    }

    private func animate(to newOpen: Bool, from p0: CGFloat) {
        open = newOpen
        animFrom = p0
        animTo = newOpen ? 1 : 0
        animStart = Date()
    }

    // MARK: Gesture

    private func drag(geo: DrawerGeometry) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .updating($dragX) { value, state, _ in
                state = value.translation.width
            }
            .onChanged { _ in if !dragging { dragging = true } }
            .onEnded { value in
                dragging = false
                let base: CGFloat = open ? 1 : 0
                let p0 = clamp01(base + value.translation.width / menuWidth)
                let projected = clamp01(base + value.predictedEndTranslation.width / menuWidth)
                animate(to: projected > 0.5, from: p0)
            }
    }

    // MARK: Controls (not 3D-transformed — always tappable)

    private var controls: some View {
        VStack {
            VStack(spacing: 3) {
                Text(style.name).font(.headline)
                Text(style.blurb)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.top, 8)

            Spacer()

            HStack(spacing: 0) {
                Button {
                    styleIndex = (styleIndex - 1 + styles.count) % max(styles.count, 1)
                } label: {
                    Image(systemName: "chevron.left").frame(width: 44, height: 44)
                }
                Spacer(minLength: 0)
                Button {
                    animate(to: !open, from: open ? 1 : 0)
                } label: {
                    Text(open ? "Close" : "Open")
                        .bold()
                        .frame(minWidth: 90)
                }
                Spacer(minLength: 0)
                Button {
                    styleIndex = (styleIndex + 1) % max(styles.count, 1)
                } label: {
                    Image(systemName: "chevron.right").frame(width: 44, height: 44)
                }
            }
            .font(.title3)
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.bottom, 6)
        }
        .tint(.primary)
        .padding(.horizontal, 24)
        .padding(.vertical, 44)
    }
}

extension DrawerStyle {
    /// Fallback shown only if the registry is empty.
    static var placeholder: DrawerStyle {
        DrawerStyle(id: "placeholder", name: "No styles", blurb: "Register a style in DrawerStyleRegistry.all") { _, _, content, _ in
            content
        }
    }
}

// MARK: - Demo content + menu (stand-ins that mirror the real app)

/// A lightweight mock of the main screen: radial-gradient backdrop + three volume
/// columns + a "Demo" pill, so rotations have rich, legible surface detail.
struct DemoContent: View {
    var body: some View {
        ZStack {
            RadialGradient(colors: [Color(white: 0.32), .black],
                           center: .center, startRadius: 5, endRadius: 620)
                .ignoresSafeArea()

            HStack(spacing: 20) {
                DemoVolumeColumn(level: 0.72, tint: .blue)
                DemoVolumeColumn(level: 0.48, tint: .green)
                DemoVolumeColumn(level: 0.61, tint: .orange)
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 90)

            VStack {
                HStack {
                    Text("Demo")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.14), in: Capsule())
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                Spacer()
            }
        }
    }
}

private struct DemoVolumeColumn: View {
    var level: CGFloat
    var tint: Color
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.white.opacity(0.10))
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(LinearGradient(colors: [tint.opacity(0.55), tint],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(height: geo.size.height * level)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            )
        }
    }
}

/// A mock of `SideBarMenuView` — dark surface, "Settings" title, icon rows.
struct DemoMenu: View {
    var safeArea: EdgeInsets = EdgeInsets()
    private let items: [(icon: String, title: String)] = [
        ("gear", "General"),
        ("wand.and.stars", "Theme"),
        ("wave.3.forward", "Receivers"),
        ("person.fill", "About")
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color("SideMenu").ignoresSafeArea()

            VStack(alignment: .leading, spacing: 6) {
                Text("Settings")
                    .font(.largeTitle.bold())
                    .padding(.bottom, 10)
                ForEach(items, id: \.icon) { item in
                    HStack(spacing: 14) {
                        Image(systemName: item.icon)
                            .font(.title3)
                            .frame(width: 26)
                        Text(item.title).font(.callout)
                        Spacer()
                    }
                    .padding(.vertical, 11)
                }
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.top, max(safeArea.top, 20) + 18)
        }
        .environment(\.colorScheme, .dark)
    }
}

// MARK: - Registry

/// The styles offered by the gallery, in display order.
enum DrawerStyleRegistry {
    static let all: [DrawerStyle] = [
        .parallaxTilt,
        .pushCard,
        .pageFlip,
        .doorSwing,
        .cubeRotate
    ]
}

// MARK: - Capture harness (driven by launch arguments)

/// Root used when the app is launched with `-prototypeCapture YES`. Reads two optional
/// args so screenshots can be deterministic:
///   `-prototypeStyleIndex N`   pin to one style (default: cycle all)
///   `-prototypeProgress F`     render STATICALLY at progress F in [0,1] (default: animate)
/// With no progress arg it shows the live auto-looping gallery (proves the driver animates).
struct PrototypeCaptureRoot: View {
    var body: some View {
        let d = UserDefaults.standard
        let styles = DrawerStyleRegistry.all
        let idx = d.object(forKey: "prototypeStyleIndex") != nil
            ? max(0, min(d.integer(forKey: "prototypeStyleIndex"), styles.count - 1))
            : -1
        let prog = d.object(forKey: "prototypeProgress") != nil ? d.double(forKey: "prototypeProgress") : -1

        if prog >= 0, idx >= 0, !styles.isEmpty {
            StaticStyleStage(style: styles[idx], progress: CGFloat(prog))
        } else if idx >= 0, !styles.isEmpty {
            PrototypeGallery(styles: [styles[idx]], autoLoop: true)
        } else {
            PrototypeGallery(autoLoop: true, autoAdvanceStyles: true)
        }
    }
}

/// Renders a single style frozen at a fixed progress — for clean, labeled comparison shots.
struct StaticStyleStage: View {
    let style: DrawerStyle
    let progress: CGFloat
    var body: some View {
        GeometryReader { proxy in
            let geo = DrawerGeometry(menuWidth: 280, size: proxy.size, safeArea: proxy.safeAreaInsets)
            ZStack(alignment: .bottom) {
                style.scene(progress, geo,
                            AnyView(DemoContent()),
                            AnyView(DemoMenu(safeArea: proxy.safeAreaInsets)))
                Text("\(style.name) · p=\(String(format: "%.2f", Double(progress)))")
                    .font(.caption).bold()
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 44)
            }
            .ignoresSafeArea()
        }
    }
}

#Preview("Prototype Gallery") {
    PrototypeGallery()
}
