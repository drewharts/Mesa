//
//  RecentlyImportedScopeToggle.swift
//  loc
//
//  DUMB Component: Near me / All pills for the profile's "Recently imported" tab,
//  with a one-line note when Near me can't be used because location is off.
//

import SwiftUI

struct RecentlyImportedScopeToggle: View {
    let selectedScope: RecentlyImportedScope
    let isLocationUnavailable: Bool
    let onSelect: (RecentlyImportedScope) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(RecentlyImportedScope.allCases) { scope in
                NearbyFilterButton(
                    title: scope.title,
                    isSelected: scope == selectedScope,
                    action: { onSelect(scope) }
                )
            }
            if isLocationUnavailable {
                Text("No location, showing all")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
    }
}
