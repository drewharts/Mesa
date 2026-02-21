//
//  ExternalPlace.swift
//  loc
//
//  Created by Assistant on current date
//

import Foundation

// MARK: - ExternalPlace Models
struct ExternalPlace: Codable, Identifiable {
    let id: String // External place ID
    let addedAt: Date
    let address: String
    let coordinates: ExternalPlaceCoordinates
    let name: String
    let placeId: String
    let source: String
    let url: String? // External video URL - metadata fetched on-demand via oEmbed
    
    enum CodingKeys: String, CodingKey {
        case id
        case addedAt = "added_at"
        case address
        case coordinates
        case name
        case placeId = "place_id"
        case source
        case url
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.addedAt = try container.decodeIfPresent(Date.self, forKey: .addedAt) ?? Date()
        self.address = try container.decodeIfPresent(String.self, forKey: .address) ?? ""
        self.coordinates = try container.decode(ExternalPlaceCoordinates.self, forKey: .coordinates)
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.placeId = try container.decodeIfPresent(String.self, forKey: .placeId) ?? ""
        self.source = try container.decodeIfPresent(String.self, forKey: .source) ?? ""
        self.url = try container.decodeIfPresent(String.self, forKey: .url)
    }
    
    // Manual initializer for creating instances
    init(id: String, addedAt: Date, address: String, coordinates: ExternalPlaceCoordinates, name: String, placeId: String, source: String, url: String?) {
        self.id = id
        self.addedAt = addedAt
        self.address = address
        self.coordinates = coordinates
        self.name = name
        self.placeId = placeId
        self.source = source
        self.url = url
    }
}

struct ExternalPlaceCoordinates: Codable {
    let latitude: Double
    let longitude: Double
} 