//
//  AnnotationDisplayMode.swift
//  loc
//
//  Controls how map annotations are displayed.
//

import Foundation

/// Controls the display mode for map annotations.
enum AnnotationDisplayMode: CaseIterable, Hashable {
    case everyone    // All annotations with profile photos
    case categories  // All annotations with category emojis
    case myPlaces    // Only current user's annotations

    /// User-facing label for the display mode.
    var label: String {
        switch self {
        case .everyone: return "Everyone"
        case .categories: return "Categories"
        case .myPlaces: return "My Places"
        }
    }

    /// SF Symbol icon name for the display mode.
    var iconName: String {
        switch self {
        case .everyone: return "person.2.fill"
        case .categories: return "face.smiling"
        case .myPlaces: return "person.fill"
        }
    }
}
