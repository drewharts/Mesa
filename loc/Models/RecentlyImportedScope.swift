//
//  RecentlyImportedScope.swift
//  loc
//
//  Which slice of the user's recent imports the profile's "Recently imported" tab shows.
//

import Foundation

/// Scope options for the profile's "Recently imported" tab.
enum RecentlyImportedScope: String, CaseIterable, Identifiable {
    /// Every recent import, newest first (the default). Listed first so the toggle reads "All | Near me".
    case all
    /// Recent imports within `RecentlyImportedViewModel.nearbyRadiusMeters` (20 miles) of the user.
    case nearMe

    var id: String { rawValue }

    /// Short label shown on the scope toggle.
    var title: String {
        switch self {
        case .all: return "All"
        case .nearMe: return "Near me"
        }
    }
}
