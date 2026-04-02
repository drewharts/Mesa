//
//  ExploreCityPill.swift
//  loc
//
//  DUMB Component: A single city filter pill for the Explore feed.
//

import SwiftUI

struct ExploreCityPill: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void



    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.mesaAccent : Color(.systemGray6))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
