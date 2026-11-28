//
//  PlaceActionPillLabel.swift
//  loc
//
//  Shared compact pill used by every button in the place detail action row.
//

import SwiftUI

struct PlaceActionPillLabel: View {
    let icon: String
    let text: String
    var isProminent: Bool = false
    /// Hides the text (keeping it for accessibility) so the pill is a compact icon button.
    var iconOnly: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
            if !iconOnly {
                Text(text)
                    .font(.system(size: 12, weight: .semibold))
            }
        }
        .foregroundColor(isProminent ? .white : .primary)
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isProminent ? Color.blue : Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.systemGray4), lineWidth: isProminent ? 0 : 0.5)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}
