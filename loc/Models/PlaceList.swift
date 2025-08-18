//
//  PlaceList.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/9/24.
//

import Foundation
import FirebaseFirestore

struct PlaceList: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var places: [Place] = []
    var city: String
    var emoji: String
    var image: String?
    var sortOrder: Int = 0 // Default to 0 for backward compatibility
    
    // NEW: Pre-calculated average coordinates for efficient sorting and map operations
    var averageCoordinate: GeoPoint?
    var lastCoordinateUpdate: Date?
}

