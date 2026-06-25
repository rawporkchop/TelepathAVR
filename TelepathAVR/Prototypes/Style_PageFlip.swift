//
//  Style_PageFlip.swift
//  TelepathAVR — animation prototype
//
//  Reference style. The content page is hinged on its LEADING edge and tilts back into
//  the screen with true perspective, sliding aside to reveal the drawer beneath. A shadow
//  gradient pools along the hinge as the page folds away (simulated light), the corners
//  round + lift, and the drawer — the facing page of a rigid "book" — starts tilted toward
//  the viewer and flattens out as it is revealed.
//

import SwiftUI

extension DrawerStyle {
    static var pageFlip: DrawerStyle {
        DrawerStyle(
            id: "pageFlip",
            name: "Book Page-Flip",
            blurb: "Content tilts back on its left hinge in real 3D; the menu is the facing page."
        ) { p, geo, content, menu in
            let w = geo.menuWidth
            let pp = clamp01(p)          // for opacities / fills that must stay in range
            return AnyView(
                ZStack(alignment: .leading) {
                    // The surface the page lifts off of.
                    Color.black.ignoresSafeArea()

                    // Drawer = facing page. Flattens from a tilt toward the viewer as it opens,
                    // so the inter-page angle stays roughly constant (a rigid book spine).
                    menu
                        .frame(width: w)
                        .frame(maxHeight: .infinity)
                        .rotation3DEffect(
                            .degrees(Double(38 * (1 - pp))),
                            axis: (x: 0, y: 1, z: 0),
                            anchor: .trailing,
                            perspective: 0.55
                        )
                        .opacity(Double(0.35 + 0.65 * pp))
                        .ignoresSafeArea()

                    // Content = the page that flips open, hinged on its leading edge.
                    content
                        .overlay(
                            // Light pooling along the hinge: the leading edge darkens as it
                            // turns away from the viewer. This shading is what sells the fold.
                            LinearGradient(
                                colors: [.black.opacity(0.6 * pp), .black.opacity(0.08 * pp), .clear],
                                startPoint: .leading,
                                endPoint: UnitPoint(x: 0.55, y: 0.5)
                            )
                            .allowsHitTesting(false)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 30 * pp, style: .continuous))
                        .shadow(color: .black.opacity(0.55 * pp), radius: 26 * pp, x: -14 * pp, y: 0)
                        .rotation3DEffect(
                            .degrees(Double(-42 * p)),
                            axis: (x: 0, y: 1, z: 0),
                            anchor: .leading,
                            perspective: 0.55
                        )
                        .offset(x: w * p)
                }
            )
        }
    }
}
