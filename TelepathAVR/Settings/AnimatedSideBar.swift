//
//  AnimatedSideBar.swift
//  TelepathAVR
//
//  Created by Oliver Larsson on 1/15/25.
//

import SwiftUI

/// A left-edge side menu (drawer). The menu is a conditionally-rendered overlay layer that
/// slides in via a transition, so it is always inside its own hit-test frame and its buttons
/// are reliably tappable. (The previous GeometryReader-offset implementation did not re-render
/// on a runtime `showMenu` change on iOS 26, and when made to slide it pushed the menu outside
/// the GeometryReader's hit-test frame, leaving the menu items dead.)
struct AnimatedSideBar<Content: View, MenuView: View, Background: View>: View {

    // Customization (kept for API compatibility with the call site)
    @Binding var rotatesWhenExpands: Bool
    var disablesInteraction: Bool = true
    var sideMenuWidth: CGFloat = 200
    var cornerRadius: CGFloat = 25
    @Binding var showMenu: Bool
    @ViewBuilder var content: (UIEdgeInsets) -> Content
    @ViewBuilder var menuView: (UIEdgeInsets) -> MenuView
    @ViewBuilder var background: Background

    private var safeArea: UIEdgeInsets {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.keyWindow?.safeAreaInsets ?? .zero
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Main content fills the screen and slides/scales aside when the menu is open.
            content(safeArea)
                .scaleEffect(rotatesWhenExpands && showMenu ? 0.92 : 1, anchor: .trailing)
                .offset(x: showMenu ? sideMenuWidth * 0.6 : 0)
                .overlay {
                    if disablesInteraction && showMenu {
                        Rectangle()
                            .fill(.black.opacity(0.35))
                            .ignoresSafeArea()
                            .onTapGesture { showMenu = false }
                            .transition(.opacity)
                    }
                }

            // The drawer: a separate overlay layer, so its buttons are always hittable.
            if showMenu {
                ZStack {
                    background
                    menuView(safeArea)
                }
                .frame(maxHeight: .infinity)
                .frame(width: sideMenuWidth)
                .transition(.move(edge: .leading))
            }
        }
        .animation(.snappy(duration: 0.3, extraBounce: 0), value: showMenu)
        // Edge-swipe to open, swipe to close. Low-priority so child controls (sliders) win.
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    if !showMenu, value.startLocation.x < 50, value.translation.width > 60 {
                        showMenu = true
                    } else if showMenu, value.translation.width < -60 {
                        showMenu = false
                    }
                }
        )
    }
}

#Preview {
    ContentView()
}
