//
//  NearbyFilterButton.swift
//  loc
//
//  DUMB Component: Capsule-style filter toggle button
//  Used by: ExternalPlacesPopupView for Recent/Nearby filter

import SwiftUI

struct NearbyFilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.black : Color.gray.opacity(0.15))
                        .animation(.easeInOut(duration: 0.2), value: isSelected)
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
