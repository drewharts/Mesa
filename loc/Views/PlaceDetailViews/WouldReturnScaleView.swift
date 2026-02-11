//
//  WouldReturnScaleView.swift
//  loc
//
//  Displays a compact "would go back" percentage indicator for a place
//

import SwiftUI

struct WouldReturnScaleView: View {
    let stats: WouldReturnStats

    var body: some View {
        HStack(spacing: 10) {
            Image("BlackLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)

            Text("Would Return")
                .font(.caption)
                .foregroundColor(.secondary)

            percentageBar

            Text(stats.formattedPercentage)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .monospacedDigit()
        }
        .padding(.bottom, 12)
    }

    // MARK: - Percentage Bar

    private var percentageBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.primary.opacity(0.1))

                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.primary.opacity(0.55))
                    .frame(width: geometry.size.width * stats.wouldReturnPercentage)
            }
        }
        .frame(height: 6)
    }
}
