//
//  ListCoverPlaceholder.swift
//  loc
//
//  Tasteful cover for lists without an image (also used while a cover loads or if it fails):
//  a deterministic soft gradient derived from the list id/name, with the list's emoji,
//  else its first letter, else a subtle map-pin symbol. Works in light and dark mode.
//

import SwiftUI

struct ListCoverPlaceholder: View {
    var seed: String
    var name: String? = nil
    var emoji: String? = nil
    var showsGlyph: Bool = true

    private static let palette: [(Color, Color)] = [
        (Color(red: 0.98, green: 0.62, blue: 0.48), Color(red: 0.93, green: 0.40, blue: 0.47)), // coral
        (Color(red: 0.47, green: 0.73, blue: 0.98), Color(red: 0.36, green: 0.47, blue: 0.93)), // sky
        (Color(red: 0.55, green: 0.85, blue: 0.68), Color(red: 0.24, green: 0.66, blue: 0.58)), // mint
        (Color(red: 0.99, green: 0.80, blue: 0.43), Color(red: 0.97, green: 0.58, blue: 0.29)), // sunset
        (Color(red: 0.78, green: 0.62, blue: 0.97), Color(red: 0.55, green: 0.41, blue: 0.90)), // lavender
        (Color(red: 0.96, green: 0.60, blue: 0.78), Color(red: 0.85, green: 0.38, blue: 0.62)), // rose
        (Color(red: 0.55, green: 0.80, blue: 0.86), Color(red: 0.30, green: 0.58, blue: 0.72))  // teal
    ]

    /// Stable (non-randomized) hash so colors don't change between launches.
    private var colors: (Color, Color) {
        var h: UInt64 = 5381
        for b in seed.utf8 { h = (h &* 33) &+ UInt64(b) }
        return Self.palette[Int(h % UInt64(Self.palette.count))]
    }

    private var glyph: String? {
        if let e = emoji?.trimmingCharacters(in: .whitespacesAndNewlines), !e.isEmpty { return e }
        if let first = name?.trimmingCharacters(in: .whitespacesAndNewlines).first(where: { $0.isLetter || $0.isNumber }) {
            return String(first).uppercased()
        }
        return nil
    }

    var body: some View {
        let c = colors
        LinearGradient(colors: [c.0, c.1], startPoint: .topLeading, endPoint: .bottomTrailing)
            .opacity(0.85)
            .overlay {
                if showsGlyph {
                    GeometryReader { geo in
                        let size = min(geo.size.width, geo.size.height)
                        Group {
                            if let g = glyph {
                                Text(g)
                                    .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.92))
                            } else {
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.system(size: size * 0.3, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.85))
                            }
                        }
                        .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
                        .frame(width: geo.size.width, height: geo.size.height)
                    }
                }
            }
            .accessibilityHidden(true)
    }
}
