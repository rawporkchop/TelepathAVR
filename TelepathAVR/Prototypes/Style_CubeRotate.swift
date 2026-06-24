//
//  Style_CubeRotate.swift
//  TelepathAVR — animation prototype
//
//  The scene turns like one face of a rigid cube. The content is the FRONT face,
//  hinged on its LEADING edge (the cube's vertical spine), swinging away to the left
//  as it rotates edge-on. The menu is the adjacent LEFT face, hinged on its TRAILING
//  edge — the SAME spine — starting edge-on (hidden) and rotating flat into view.
//  Because both faces pivot about the shared spine under one strong perspective, they
//  read as two rigid faces of a single cube turning, joined at the seam rather than
//  two detached panels. A darkening shade pools on the content as it turns edge-on, and
//  a seam shadow anchors the hinge.
//

import SwiftUI

extension DrawerStyle {
    static var cubeRotate: DrawerStyle {
        DrawerStyle(
            id: "cubeRotate",
            name: "Cube Rotate",
            blurb: "Two rigid faces of a cube hinge on a shared spine: content turns away as the menu turns in."
        ) { p, geo, content, menu in
            let w = geo.menuWidth
            let pp = clamp01(p)                 // for opacities / fills that must stay in range
            let perspective: CGFloat = 0.7      // shared strong perspective — same cube

            return AnyView(
                ZStack(alignment: .leading) {
                    // Cube interior backdrop.
                    Color.black.ignoresSafeArea()

                    // LEFT face = menu. Hinged on its TRAILING edge (the spine at x = w).
                    // Starts edge-on (+88°, effectively invisible) and rotates flat to 0°
                    // as it comes into view. Its trailing edge is pinned to the spine, so it
                    // shares the hinge with the content face.
                    menu
                        .frame(width: w)
                        .frame(maxHeight: .infinity)
                        .overlay(
                            // Light falloff: the face is dim while still edge-on, brightening
                            // (shade clears) as it rotates flat toward the viewer.
                            LinearGradient(
                                colors: [.black.opacity(0.55 * (1 - pp)), .clear],
                                startPoint: .trailing,
                                endPoint: .leading
                            )
                            .allowsHitTesting(false)
                        )
                        .rotation3DEffect(
                            .degrees(Double(88 * (1 - p))),
                            axis: (x: 0, y: 1, z: 0),
                            anchor: .trailing,
                            perspective: perspective
                        )
                        .opacity(Double(clamp01(p * 1.6)))   // fade the sliver in as it opens
                        .ignoresSafeArea()

                    // FRONT face = content. Hinged on its LEADING edge and offset right by
                    // w * p so that leading edge lands exactly on the spine (x = w) when open —
                    // the SAME line the menu pivots on. Rotates 0° -> -88° to swing edge-on.
                    content
                        .overlay(
                            // Shade pools across the surface as it turns edge-on, darkest at
                            // the hinge (leading edge). This is what sells the cube-face turn.
                            LinearGradient(
                                colors: [.black.opacity(0.7 * pp), .black.opacity(0.25 * pp), .clear],
                                startPoint: .leading,
                                endPoint: UnitPoint(x: 0.7, y: 0.5)
                            )
                            .allowsHitTesting(false)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 26 * pp, style: .continuous))
                        // Seam shadow at the hinge for elevation over the menu face.
                        .shadow(color: .black.opacity(0.6 * pp), radius: 22 * pp, x: -16 * pp, y: 0)
                        .rotation3DEffect(
                            .degrees(Double(-88 * p)),
                            axis: (x: 0, y: 1, z: 0),
                            anchor: .leading,
                            perspective: perspective
                        )
                        .offset(x: w * p)
                }
            )
        }
    }
}
