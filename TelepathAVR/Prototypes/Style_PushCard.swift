//
//  Style_PushCard.swift
//  TelepathAVR — animation prototype
//
//  The content page is pushed back into 3D space like a card shoved into a stack: as the
//  menu opens it slides aside, scales down, and tilts a few degrees on its LEADING edge with
//  true perspective, casting a soft drop shadow onto the menu beneath it. A thin specular
//  highlight rides the top edge so the card reads as a lifted, glossy slab. The menu sits
//  BEHIND with subtle parallax — it trails the content in (slower) and eases from dim +
//  slightly scaled-down up to full brightness as it is revealed.
//

import SwiftUI

extension DrawerStyle {
    static var pushCard: DrawerStyle {
        DrawerStyle(
            id: "pushCard",
            name: "Push Card",
            blurb: "Content slides aside, scales down and tilts back into 3D, floating a soft shadow over the menu."
        ) { p, geo, content, menu in
            let w = geo.menuWidth
            let pp = clamp01(p)          // for opacities / fills / corner radius that must stay in range
            let d = Double(pp)           // opacity / brightness take Double, not CGFloat
            return AnyView(
                ZStack(alignment: .leading) {
                    // The void the card lifts off of.
                    Color.black.ignoresSafeArea()

                    // Menu, BEHIND the content. Parallax: it trails in, starting offset to the
                    // left and easing to 0 so it moves slower than the card. It also scales up
                    // and brightens from dim as it is revealed.
                    menu
                        .frame(width: w)
                        .frame(maxHeight: .infinity)
                        .scaleEffect(lerp(0.92, 1.0, pp))
                        .brightness(Double(lerp(-0.4, 0, pp)))
                        .opacity(Double(lerp(0.6, 1.0, pp)))
                        .offset(x: lerp(-w * 0.25, 0, pp))
                        .ignoresSafeArea()

                    // Content = the card pushed back into the stack, hinged on its leading edge.
                    content
                        .overlay(
                            // A thin bright specular highlight skimming the top edge — sells the
                            // glossy lifted slab as it floats above the menu.
                            LinearGradient(
                                colors: [.white.opacity(0.45 * d), .clear],
                                startPoint: .top,
                                endPoint: UnitPoint(x: 0.5, y: 0.12)
                            )
                            .allowsHitTesting(false)
                        )
                        .overlay(
                            // Ambient occlusion: the leading edge darkens slightly as it turns
                            // away from the viewer, deepening the pushed-back read.
                            LinearGradient(
                                colors: [.black.opacity(0.28 * d), .clear],
                                startPoint: .leading,
                                endPoint: UnitPoint(x: 0.4, y: 0.5)
                            )
                            .allowsHitTesting(false)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 28 * pp, style: .continuous))
                        // Soft drop shadow that grows so the card visibly floats above the menu.
                        .shadow(color: .black.opacity(0.5 * d), radius: 30 * pp, x: -16 * pp, y: 10 * pp)
                        // Scale down slightly as it is pushed back into the stack.
                        .scaleEffect(lerp(1.0, 0.86, pp))
                        // Tilt a few degrees on the leading hinge, with real perspective.
                        .rotation3DEffect(
                            .degrees(Double(-12 * p)),
                            axis: (x: 0, y: 1, z: 0),
                            anchor: .leading,
                            perspective: 0.5
                        )
                        // Slide aside to reveal the menu beneath.
                        .offset(x: w * p)
                }
            )
        }
    }
}
