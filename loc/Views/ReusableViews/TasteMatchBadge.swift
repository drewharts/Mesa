//
//  TasteMatchBadge.swift
//  loc
//
//  Compact "92% taste match" pill for profile headers (and reusable in rows).
//  Shows a shimmer skeleton while loading, a muted hint when data is sparse,
//  and nothing at all if the lookup failed.
//

import SwiftUI

struct TasteMatchBadge: View {
    let match: TasteMatch?
    let isLoading: Bool
    var compact: Bool = false

    var body: some View {
        Group {
            if isLoading {
                SkeletonBlock(width: compact ? 70 : 150, height: compact ? 18 : 24, cornerRadius: 12)
            } else if let match, match.enoughData, let score = match.score {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: compact ? 10 : 12, weight: .semibold))
                    Text("\(score)% taste match")
                        .font(.system(size: compact ? 11 : 13, weight: .semibold))
                    if !compact, let label = match.sharedCategoryLabel {
                        Text("· \(label)")
                            .font(.system(size: 12, weight: .regular))
                            .opacity(0.85)
                            .lineLimit(1)
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, compact ? 8 : 10)
                .padding(.vertical, compact ? 3 : 5)
                .background(Capsule().fill(Self.gradient(for: score)))
                .accessibilityLabel("\(score) percent taste match")
                .loadFadeIn()
            } else if let match, !match.enoughData, !compact {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles").font(.system(size: 11))
                    Text("Not enough saves yet for a taste match")
                        .font(.system(size: 12))
                }
                .foregroundColor(.secondary)
                .loadFadeIn()
            }
        }
        .animation(.easeOut(duration: 0.22), value: isLoading)
    }

    static func gradient(for score: Int) -> LinearGradient {
        let colors: [Color]
        switch score {
        case 75...: colors = [Color(red: 0.98, green: 0.36, blue: 0.45), Color(red: 0.99, green: 0.58, blue: 0.27)]
        case 50..<75: colors = [Color(red: 0.55, green: 0.36, blue: 0.96), Color(red: 0.93, green: 0.36, blue: 0.62)]
        default: colors = [Color(red: 0.36, green: 0.52, blue: 0.96), Color(red: 0.45, green: 0.72, blue: 0.96)]
        }
        return LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
    }
}
