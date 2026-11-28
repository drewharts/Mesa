//
//  ReserveActionLabel.swift
//  loc
//
//  Action-row label for the Reserve button showing the reservation provider's logo.
//

import SwiftUI

struct ReserveActionLabel: View {
    let link: ReservationLink

    private let logoHeight: CGFloat = 18

    var body: some View {
        HStack(spacing: 6) {
            icon
            Text(link.buttonLabelText)
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundColor(.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(link.buttonTitle)
        .accessibilityAddTraits(.isButton)
    }

    /// Provider logo when known, otherwise the generic calendar symbol.
    @ViewBuilder
    private var icon: some View {
        if let asset = link.logoAssetName {
            Image(asset)
                .resizable()
                .scaledToFit()
                .frame(width: logoHeight, height: logoHeight)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        } else {
            Image(systemName: "calendar")
                .font(.system(size: 14, weight: .medium))
                .frame(height: logoHeight)
        }
    }
}
