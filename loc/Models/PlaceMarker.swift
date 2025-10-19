//
//  PlaceMarker.swift
//  loc
//
//  Created by Assistant on optimized map marker implementation
//

import Foundation
import CoreLocation

/// Minimal place data for map markers - only essential info for rendering
struct PlaceMarker: Identifiable, Codable {
    let id: UUID
    let name: String
    let latitude: Double
    let longitude: Double
    let placeId: String
    let isCustom: Bool
    
    /// Computed coordinate for map display
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case latitude
        case longitude
        case placeId = "place_id"
        case isCustom = "is_custom"
    }
}

/// Response from the minimal viewport query
struct PlaceMarkerResponse: Codable {
    let id: UUID
    let name: String
    let latitude: Double
    let longitude: Double
    let placeId: String
    let isCustom: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case latitude
        case longitude
        case placeId = "place_id"
        case isCustom = "is_custom"
    }
    
    /// Convert to PlaceMarker
    func toPlaceMarker() -> PlaceMarker {
        PlaceMarker(
            id: id,
            name: name,
            latitude: latitude,
            longitude: longitude,
            placeId: placeId,
            isCustom: isCustom
        )
    }
}
