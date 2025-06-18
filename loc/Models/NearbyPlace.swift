//  NearbyPlace.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/12/24.
//

import Foundation

// MARK: - Main Response
struct NearbyPlacesResponse: Codable {
    let features: [NearbyPlaceFeature]
    let metadata: NearbyPlacesMetadata
    let type: String
}

// MARK: - Feature
struct NearbyPlaceFeature: Codable, Identifiable {
    let geometry: NearbyPlaceGeometry
    let properties: NearbyPlaceProperties
    let type: String
    
    var id: String {
        return properties.actualId
    }
}

// MARK: - Geometry
struct NearbyPlaceGeometry: Codable {
    let coordinates: [Double] // [longitude, latitude]
    let type: String
    
    var latitude: Double {
        return coordinates[1]
    }
    
    var longitude: Double {
        return coordinates[0]
    }
}

// MARK: - Properties
struct NearbyPlaceProperties: Codable {
    // Common fields (present in both Google Places and Firestore)
    let address: String
    let distanceMeters: Double?  // Made optional to handle missing values
    let name: String
    let source: String?
    
    // Google Places specific fields (optional)
    let businessStatus: String?
    let createdAt: String?
    let openNow: Bool?
    let permanentlyClosed: Bool?
    let photoReference: String?
    let priceLevel: Int?
    let rating: Double?
    let types: [String]?
    let updatedAt: String?
    let userRatingsTotal: Int?
    
    // Firestore specific fields (optional)
    let description: String?
    let id: String?
    
    // Place ID handling (Google has place_id, Firestore has id or null place_id)
    let placeId: String?
    
    // Computed property to get the actual ID
    var actualId: String {
        // For Firestore places, use the id field
        if let firestoreId = id {
            return firestoreId
        }
        // For Google Places, use place_id
        if let googlePlaceId = placeId {
            return googlePlaceId
        }
        // Fallback to name-based ID
        return name.replacingOccurrences(of: " ", with: "_")
    }
    
    enum CodingKeys: String, CodingKey {
        case address
        case businessStatus = "business_status"
        case createdAt = "created_at"
        case distanceMeters = "distance_meters"
        case name
        case openNow = "open_now"
        case permanentlyClosed = "permanently_closed"
        case photoReference = "photo_reference"
        case placeId = "place_id"
        case priceLevel = "price_level"
        case rating
        case source
        case types
        case updatedAt = "updated_at"
        case userRatingsTotal = "user_ratings_total"
        case description
        case id
    }
}

// MARK: - Metadata
struct NearbyPlacesMetadata: Codable {
    let cacheHit: Bool
    let dataSource: String
    let placeType: String?
    let radiusMeters: Int
    let searchLocation: SearchLocation
    let totalResults: Int
    
    enum CodingKeys: String, CodingKey {
        case cacheHit = "cache_hit"
        case dataSource = "data_source"
        case placeType = "place_type"
        case radiusMeters = "radius_meters"
        case searchLocation = "search_location"
        case totalResults = "total_results"
    }
}

// MARK: - Search Location
struct SearchLocation: Codable {
    let latitude: Double
    let longitude: Double
} 