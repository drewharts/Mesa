//
//  ExploreList.swift
//  loc
//
//  Public list and city models for the Explore tab. Built client-side from existing
//  `place_lists` rows; there is no server-side popularity metric.
//

import Foundation
import CoreLocation

/// A public list surfaced on the Explore tab.
struct ExploreList: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let city: String?
    let imageURL: String?
    let ownerId: String
    let placeCount: Int
    let createdAt: String?
    let updatedAt: String?
    let latitude: Double?
    let longitude: Double?
    var ownerName: String? = nil
    var ownerPhotoURL: String? = nil

    /// The list's average location, when it has one.
    var location: CLLocation? {
        guard let latitude, let longitude else { return nil }
        return CLLocation(latitude: latitude, longitude: longitude)
    }

    /// "12 places" / "1 place" caption.
    var placeCountLabel: String {
        "\(placeCount) place\(placeCount == 1 ? "" : "s")"
    }
}

/// A city aggregated from public lists, with how many lists cover it.
struct ExploreCity: Identifiable, Hashable, Codable {
    let key: String
    let name: String
    /// Every raw `city` spelling folded into this entry (used to query its lists).
    let rawNames: [String]
    let listCount: Int

    var id: String { key }

    /// "3 lists" / "1 list" caption.
    var listCountLabel: String {
        "\(listCount) list\(listCount == 1 ? "" : "s")"
    }
}

/// Owner display info attached to explore lists after a batched user lookup.
struct ExploreListOwner {
    let name: String
    let photoURL: String?
}

/// Sort options for a city's lists.
enum ExploreListSort: String, CaseIterable, Identifiable {
    case popular = "Popular"
    case newest = "Newest"
    case mostPlaces = "Most places"

    var id: String { rawValue }
}
