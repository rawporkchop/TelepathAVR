//
//  Style_ParallaxTilt.swift
//  TelepathAVR — animation prototype
//
//  The restrained, native-feeling option. The content slides fully aside with a GENTLE
//  ~9deg tilt on its leading edge and a soft elevation shadow, while the menu parallaxes
//  in behind it — moving slower than the content — and brightens + grows very slightly as
//  it settles. No dramatic fold: just tasteful depth. The "safe to ship" choice that still
//  reads as 3D.
//

import SwiftUI

extension DrawerStyle {
    static var parallaxTilt: DrawerStyle {
        DrawerStyle(
            id: "parallaxTilt",
            name: "Parallax Tilt",
            blurb: "Content slides aside with a gentle 9° tilt; the menu parallaxes in behind it and brightens."
        ) { p, geo, content, menu in
            let w = geo.menuWidth
            let pp = clamp01(p)          // opacities / fills that must stay in [0,1]
            return AnyView(
                ZStack(alignment: .leading) {
                    // The dark surface the content lifts off of.
                    Color.black.ignoresSafeArea()

                    // Menu parallaxes in from behind — moving SLOWER than the content
                    // (only ~65% of its travel), brightening and growing a touch as it lands.
                    menu
                        .frame(width: w)
                        .frame(maxHeight: .infinity)
                        .scaleEffect(lerp(0.96, 1.0, pp))
                        .opacity(Double(lerp(0.70, 1.0, pp)))
                        .offset(x: lerp(-w * 0.35, 0, pp))
                        .ignoresSafeArea()

                    // Content = the page that slides aside with a mild backward tilt.
                    // Small angle + mild perspective keeps it native, not dramatic.
                    content
                        .overlay(
                            // Very light leading-edge darkening as the page turns away — the
                            // subtle shading that grounds the tilt. Capped low for restraint.
                            LinearGradient(
                                colors: [.black.opacity(Double(0.22 * pp)), .clear],
                                startPoint: .leading,
                                endPoint: UnitPoint(x: 0.4, y: 0.5)
                            )
                            .allowsHitTesting(false)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 24 * pp, style: .continuous))
                        .shadow(color: .black.opacity(Double(0.35 * pp)), radius: 18 * pp, x: -8 * pp, y: 0)
                        .rotation3DEffect(
                            .degrees(Double(-9 * p)),
                            axis: (x: 0, y: 1, z: 0),
                            anchor: .leading,
                            perspective: 0.35
                        )
                        .offset(x: w * p)
                }
            )
        }
    }
}
