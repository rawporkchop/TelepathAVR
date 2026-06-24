//
//  Style_DoorSwing.swift
//  TelepathAVR — animation prototype
//
//  The content swings open like a hinged glass door. It is hinged on its LEADING edge
//  and rotates outward toward the viewer with real perspective, sliding aside (a door
//  swings farther than it slides) to reveal the menu standing behind it. A narrow,
//  glossy specular highlight sweeps diagonally across the door surface as the angle
//  changes — its gradient stops travel via lerp on UnitPoints — while an ambient
//  hinge-side darkening grounds the fold. The swung-open edge casts a soft drop shadow
//  onto the menu for elevation. The menu fades and scales up gently behind, barely
//  rotating, so it reads as a flat plane the door peels off of.
//

import SwiftUI

extension DrawerStyle {
    static var doorSwing: DrawerStyle {
        DrawerStyle(
            id: "doorSwing",
            name: "Door Swing",
            blurb: "Content swings open on a leading hinge in real 3D; a glossy sheen sweeps the glass door."
        ) { p, geo, content, menu in
            let w = geo.menuWidth
            let pp = clamp01(p)                 // for opacities / fills / scale that must stay sane

            // Moving specular band: a narrow bright diagonal that slides across the door
            // as it swings. Both endpoints travel via lerp on UnitPoint coordinates.
            let sheenStart = UnitPoint(x: lerp(-0.30, 0.55, pp), y: lerp(0.05, 0.0, pp))
            let sheenEnd   = UnitPoint(x: lerp(0.10, 1.05, pp),  y: lerp(0.55, 0.95, pp))

            return AnyView(
                ZStack(alignment: .leading) {
                    // The dark void the door opens into.
                    Color.black.ignoresSafeArea()

                    // Menu = the plane standing behind the door. Barely rotates; fades and
                    // scales up gently as it is revealed (parallax: it moves far less than
                    // the swinging content).
                    menu
                        .frame(width: w)
                        .frame(maxHeight: .infinity)
                        .scaleEffect(lerp(0.94, 1.0, pp), anchor: .leading)
                        .rotation3DEffect(
                            .degrees(Double(6 * (1 - pp))),
                            axis: (x: 0, y: 1, z: 0),
                            anchor: .leading,
                            perspective: 0.6
                        )
                        .opacity(Double(lerp(0.5, 1.0, pp)))
                        .offset(x: w * pp * 0.12)
                        .ignoresSafeArea()

                    // Content = the glass door, hinged on its leading edge.
                    content
                        .overlay(
                            // Ambient hinge-side darkening: the leading edge turns away from
                            // the light as the door swings, so it pools into shadow.
                            LinearGradient(
                                colors: [.black.opacity(Double(0.5 * pp)), .black.opacity(Double(0.06 * pp)), .clear],
                                startPoint: .leading,
                                endPoint: UnitPoint(x: 0.5, y: 0.5)
                            )
                            .allowsHitTesting(false)
                        )
                        .overlay(
                            // Moving glossy specular sheen — a narrow bright band that sweeps
                            // across the surface. Composited with .screen so it brightens
                            // without flattening the underlying art.
                            LinearGradient(
                                stops: [
                                    .init(color: .clear,                            location: 0.0),
                                    .init(color: .white.opacity(0.0),               location: 0.40),
                                    .init(color: .white.opacity(Double(0.55 * pp)), location: 0.50),
                                    .init(color: .white.opacity(0.0),               location: 0.60),
                                    .init(color: .clear,                            location: 1.0)
                                ],
                                startPoint: sheenStart,
                                endPoint: sheenEnd
                            )
                            .blendMode(.screen)
                            .allowsHitTesting(false)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 34 * pp, style: .continuous))
                        // Soft shadow cast by the swung-open edge onto the menu behind.
                        .shadow(color: .black.opacity(Double(0.55 * pp)), radius: 30 * pp, x: -18 * pp, y: 0)
                        .rotation3DEffect(
                            .degrees(Double(-58 * p)),
                            axis: (x: 0, y: 1, z: 0),
                            anchor: .leading,
                            perspective: 0.6
                        )
                        // Slide aside by the full menu width so the menu is fully revealed
                        // (usable) when open, while the leading-edge swing supplies the drama.
                        .offset(x: w * p)
                }
            )
        }
    }
}
