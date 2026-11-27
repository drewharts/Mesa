//
//  MapTopBar.swift
//  loc
//
//  DUMB Component: floating top row of the map screen — the search pill plus exactly one
//  action button (Fresh finds, the swipe deck).
//

import SwiftUI

/// Search pill with a single Fresh finds button beside it.
struct MapTopBar: View {
    let onSearchTap: () -> Void
    let onFreshFindsTap: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            MapSearchBar(onTap: onSearchTap)
            MapCircleButton(
                systemName: "sparkles",
                tint: .orange,
                accessibilityLabel: "Fresh finds",
                action: onFreshFindsTap
            )
            .accessibilityIdentifier("map.freshFinds")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}
