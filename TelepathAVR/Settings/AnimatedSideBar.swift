//
//  AnimatedSideBar.swift
//  TelepathAVR
//
//  Created by Oliver Larsson on 1/15/25.
//

import SwiftUI

/// Open/close state + Push Card animation driver for the side drawer.
///
/// A **reference type on purpose.** On iOS 26 this app's view tree does not re-render
/// `AnimatedSideBar` when its inputs change — `ContentView.body` re-evaluates and hands down a fresh
/// `showMenu`, but the drawer's `body` is never re-invoked (verified empirically). The only ways to
/// reflect a change are an `.id(...)` identity swap (which rebuilds fresh and therefore SNAPS) or to
/// read the value live every frame from a stable reference. The smooth transition needs the latter:
/// the display clock below reads `isOpen` (and the ease anchors) off this object every frame, so an
/// open/close animates without any view-tree invalidation. Mutating these from a gesture or task and
/// reading them next frame is the whole mechanism.
final class DrawerController: ObservableObject {
    /// Public open/close intent. Set by the call site (e.g. the connect alert) and by the gestures.
    @Published var isOpen: Bool

    // Driver internals — read live every frame by the clock, mutated off-render. Plain (non-published)
    // because the clock already reads the live object; they never need to invalidate anything.
    /// The open state the current ease is heading to (lags `isOpen` until `reconcile` picks it up).
    var committed: Bool
    var animFrom: CGFloat
    var animTo: CGFloat
    var animStart: Date = .distantPast
    var dragging: Bool = false
    var dragTranslation: CGFloat = 0

    init(isOpen: Bool = false) {
        self.isOpen = isOpen
        self.committed = isOpen
        self.animFrom = isOpen ? 1 : 0
        self.animTo = isOpen ? 1 : 0
    }
}

/// A left-edge side menu (drawer) opened with a left-to-right edge swipe, rendered with the
/// **Push Card** transition (see `Style_PushCard`): the content page slides aside, scales down
/// and tilts back into 3D — floating a soft drop shadow over the menu — while the menu trails in
/// behind it with subtle parallax, brightening from dim as it is revealed.
///
/// WHY A DISPLAY-CLOCK DRIVER (iOS 26)
/// -----------------------------------
/// This view does not re-render on a state change here (see `DrawerController`). So the motion is
/// driven analytically from a `TimelineView(.animation)` display clock: every frame it reads the
/// drawer's `(from → to, start-time)` snapshot off the shared object, computes `progress`, and hands
/// it to the Push Card style. The clock produces the in-between frames the snapping view tree cannot,
/// which is what makes the open/close smooth rather than an instant jump.
///
/// Everything the clock depends on (open intent, ease anchors, live drag) therefore lives on the
/// `DrawerController` reference, read fresh each frame. The flat gesture catchers live inside the
/// closure too so they track the committed state. Reactive *content* state (e.g. the Theme sub-page)
/// is refreshed by the call site re-`id`-ing this view, since that genuinely needs a rebuild.
///
/// The gesture catchers are deliberately NOT 3D-transformed: hit-testing through a
/// `rotation3DEffect` perspective is unreliable, so opening/closing is caught by flat overlays —
/// a narrow leading edge strip (when closed) and an invisible content-region catcher (when open).
/// The menu is made inert (not hittable, hidden from accessibility) while closed so it neither
/// steals touches from the content nor leaks into the accessibility tree behind it.
struct AnimatedSideBar<Content: View, MenuView: View, Background: View>: View {

    // Customization (kept for API compatibility with the call site). `rotatesWhenExpands` and
    // `cornerRadius` are honoured by the Push Card style internally, so they are retained but not
    // read here.
    @Binding var rotatesWhenExpands: Bool
    var disablesInteraction: Bool = true
    var sideMenuWidth: CGFloat = 200
    var cornerRadius: CGFloat = 25

    /// Shared open/close intent + animation driver. Read live every frame by the clock below.
    @ObservedObject var drawer: DrawerController

    @ViewBuilder var content: (UIEdgeInsets) -> Content
    @ViewBuilder var menuView: (UIEdgeInsets) -> MenuView
    @ViewBuilder var background: Background

    /// The drawer animation. Swap this single line to use a different prototype style app-wide.
    private let style: DrawerStyle = .pushCard

    /// Open/close ease length, seconds.
    private let duration: Double = 0.5

    /// Width of the leading hit strip that opens the drawer. Kept narrow so mid-screen swipes
    /// (zone switching, gated to x > 50) and the slider resize grip are never affected.
    private let edgeOpenZone: CGFloat = 28

    private var safeArea: UIEdgeInsets {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.keyWindow?.safeAreaInsets ?? .zero
    }

    var body: some View {
        let ui = safeArea
        // Push Card only needs `menuWidth`; build geometry directly (no GeometryReader, which on
        // iOS 26 would not re-render here anyway).
        let geo = DrawerGeometry(
            menuWidth: sideMenuWidth,
            size: UIScreen.main.bounds.size,
            safeArea: EdgeInsets(top: ui.top, leading: ui.left, bottom: ui.bottom, trailing: ui.right)
        )

        return TimelineView(.animation) { tl in
            // Reconcile the public intent against the committed state, INSIDE the clock: an external
            // open/close does not re-render this body, but reading the object is always live and this
            // closure runs every frame.
            let _ = reconcile()
            let p = progress(at: tl.date)
            ZStack(alignment: .leading) {
                // Push Card scene: content card pushed back over the menu. Content is inert while
                // open; the menu is inert (and hidden from accessibility) while closed.
                style.scene(
                    p,
                    geo,
                    AnyView(content(ui).disabled(drawer.committed)),
                    AnyView(menuSurface(ui)
                        .allowsHitTesting(drawer.committed)
                        .accessibilityHidden(!drawer.committed))
                )

                // Flat (non-3D) gesture catchers, inside the clock so they track the committed state.
                gestureCatchers()
            }
        }
        .ignoresSafeArea()
    }

    /// Start an ease whenever the public `isOpen` diverges from the committed state. Called every
    /// frame from inside the clock; the actual mutation is hopped to a `@MainActor` task so it never
    /// runs during view evaluation. The guards make all but the first call a no-op, so the run of
    /// frames before the task lands does not stack up competing eases.
    private func reconcile() {
        guard !drawer.dragging, drawer.isOpen != drawer.committed else { return }
        Task { @MainActor in
            guard !drawer.dragging, drawer.isOpen != drawer.committed else { return }
            animate(to: drawer.isOpen, from: progress(at: Date()))
        }
    }

    // MARK: Menu surface (background fill + the caller's menu content)

    /// The drawer pane handed to the style: the `.sideMenu` backing plus the caller's menu items.
    /// The style frames it to `menuWidth` and positions it on the leading edge.
    @ViewBuilder private func menuSurface(_ ui: UIEdgeInsets) -> some View {
        ZStack {
            background
            menuView(ui)
        }
    }

    // MARK: Driver

    /// Resting progress for the committed open state.
    private var resting: CGFloat { drawer.committed ? 1 : 0 }

    /// Progress to show at `now`: follow the finger while dragging, otherwise play the eased
    /// animation from the last snapshot.
    private func progress(at now: Date) -> CGFloat {
        if drawer.dragging {
            return clamp01(resting + drawer.dragTranslation / sideMenuWidth)
        }
        let elapsed = now.timeIntervalSince(drawer.animStart)
        if elapsed >= duration { return drawer.animTo }
        let t = CGFloat(elapsed / duration)
        return drawer.animFrom + (drawer.animTo - drawer.animFrom) * easeInOutCubic(t)
    }

    /// Begin an ease toward `newOpen`, starting from progress `p0`.
    private func animate(to newOpen: Bool, from p0: CGFloat) {
        drawer.committed = newOpen
        drawer.animFrom = p0
        drawer.animTo = newOpen ? 1 : 0
        drawer.animStart = Date()
    }

    // MARK: Gestures

    /// Open: track left-to-right drag live, commit on release or flick. `.global` keeps the math
    /// correct despite the content's offset/rotation.
    private var openDrag: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .onChanged { value in
                drawer.dragging = true
                drawer.dragTranslation = max(0, value.translation.width)
            }
            .onEnded { value in
                let commit = value.translation.width > sideMenuWidth * 0.35
                    || value.predictedEndTranslation.width > sideMenuWidth
                settle(to: commit)
            }
    }

    /// Close: track right-to-left drag live, commit on release or flick.
    private var closeDrag: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .onChanged { value in
                drawer.dragging = true
                drawer.dragTranslation = min(0, value.translation.width)
            }
            .onEnded { value in
                let close = value.translation.width < -sideMenuWidth * 0.35
                    || value.predictedEndTranslation.width < -sideMenuWidth
                settle(to: !close)
            }
    }

    /// Resolve a finished drag: ease from the released finger position to the committed state and
    /// publish it. `animate` sets `committed` first, so `reconcile` sees parity and does not start a
    /// second, competing ease.
    private func settle(to newOpen: Bool) {
        let p0 = clamp01(resting + drawer.dragTranslation / sideMenuWidth)
        drawer.dragging = false
        drawer.dragTranslation = 0
        animate(to: newOpen, from: p0)
        if drawer.isOpen != newOpen { drawer.isOpen = newOpen }
    }

    // MARK: Catchers (flat, never 3D-transformed)

    @ViewBuilder private func gestureCatchers() -> some View {
        // Close: an invisible catcher over the content region (everything right of the menu).
        // A non-hittable clear spacer the width of the menu keeps the menu itself tappable; the
        // catcher closes on tap or reverse-swipe. No visible scrim — the Push Card's own shadow
        // and ambient occlusion already separate the lifted card from the menu beneath it.
        if disablesInteraction && drawer.committed {
            HStack(spacing: 0) {
                Color.clear
                    .frame(width: sideMenuWidth)
                    .allowsHitTesting(false)
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { drawer.isOpen = false }
                    .highPriorityGesture(closeDrag)
            }
            .ignoresSafeArea()
        }

        // Open: a dedicated, front-most leading-edge catcher, present only while closed so it never
        // blocks content interaction once open.
        if !drawer.committed {
            HStack(spacing: 0) {
                Color.clear
                    .frame(width: edgeOpenZone)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .highPriorityGesture(openDrag)
                Spacer(minLength: 0).allowsHitTesting(false)
            }
            .ignoresSafeArea()
        }
    }
}

#Preview {
    ContentView()
}
