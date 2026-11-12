//
//  RecentlyImportedScopeToggle.swift
//  loc
//
//  DUMB Component: All / Near me pills for the map's imports sheet. Near me is dimmed and
//  unselectable when there is no location, with a short "Location off" note.
//

import SwiftUI

struct RecentlyImportedScopeToggle: View {
    let selectedScope: RecentlyImportedScope
    let isNearMeAvailable: Bool
    let onSelect: (RecentlyImportedScope) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(RecentlyImportedScope.allCases) { scope in
                let isEnabled = scope == .all || isNearMeAvailable
                NearbyFilterButton(
                    title: scope.title,
                    isSelected: scope == selectedScope,
                    action: { onSelect(scope) }
                )
                .disabled(!isEnabled)
                .opacity(isEnabled ? 1 : 0.4)
            }
            if !isNearMeAvailable {
                Text("Location off")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
