//  PhotoLocationCluster.swift
//  loc
//
//  Data model representing a group of photos clustered by GPS proximity.

import Foundation

struct PhotoLocationCluster: Identifiable {
    let id: UUID = UUID()
    var latitude: Double
    var longitude: Double
    var photoIndices: [Int]
    var nearbyPlaces: [NearbyPlaceFeature]
    var selectedPlace: NearbyPlaceFeature?
    var resolvedPlace: DetailPlace?
    var isLoadingPlaces: Bool
    var searchRadiusUsed: Int
    var isReviewed: Bool

    /// Human-readable address hint derived from the first nearby place, or a coordinate fallback.
    var addressHint: String {
        if let firstPlace = nearbyPlaces.first {
            return "Near \(firstPlace.properties.name)"
        }
        return String(format: "%.4f, %.4f", latitude, longitude)
    }
}
