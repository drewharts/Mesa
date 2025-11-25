//
//  PlaceAnnotation.swift
//  loc
//
//  Created by Assistant on optimized map annotation implementation
//

import Foundation
import CoreLocation

/// Place annotation data returned from PostgreSQL function
struct PlaceAnnotation: Identifiable, Codable {
    let id: String
    let name: String
    let coordinate: CLLocationCoordinate2D
    let userIds: [String] // Array of user IDs who saved this place
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case coordinate
        case userIds = "user_ids"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        userIds = try container.decode([String].self, forKey: .userIds)
        
        // Parse coordinate from PostGIS GeoJSON format: {"type": "Point", "coordinates": [longitude, latitude]}
        let coordinateData = try container.decode(CoordinateData.self, forKey: .coordinate)
        if let coords = coordinateData.coordinates, coords.count >= 2 {
            coordinate = CLLocationCoordinate2D(latitude: coords[1], longitude: coords[0])
        } else {
            print("⚠️ [PlaceAnnotation] Failed to parse coordinate data")
            coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        }
    }
}

/// Coordinate data structure for parsing GeoJSON geometry
struct CoordinateData: Codable {
    let type: String?
    let coordinates: [Double]?
    
    enum CodingKeys: String, CodingKey {
        case type
        case coordinates
    }
}
