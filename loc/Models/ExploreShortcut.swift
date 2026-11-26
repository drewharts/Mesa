//
//  ExploreShortcut.swift
//  loc
//
//  Feature sheets reachable from the Explore tab's shortcut cards.
//

import Foundation

/// A feature the Explore tab can open in a sheet.
enum ExploreShortcut: String, Identifiable {
    case tonight
    case freshFinds

    var id: String { rawValue }
}
