//
//  GeoJSONModels.swift
//  loc
//
//  Codable models for parsing Natural Earth GeoJSON country boundaries.
//

import Foundation

struct GeoJSONFeatureCollection: Codable {
    let type: String
    let features: [GeoJSONFeature]
}

struct GeoJSONFeature: Codable {
    let type: String
    let properties: GeoJSONProperties
    let geometry: GeoJSONGeometry
}

struct GeoJSONProperties: Codable {
    let isoA2: String?
    let admin: String?

    enum CodingKeys: String, CodingKey {
        case isoA2 = "ISO_A2"
        case admin = "ADMIN"
    }
}

struct GeoJSONGeometry: Codable {
    let type: String
    let coordinates: GeoJSONCoordinates

    /// Decoded coordinate rings, structured by geometry type.
    enum GeoJSONCoordinates {
        /// Polygon: array of rings, each ring is [[lon, lat]]
        case polygon([[[Double]]])
        /// MultiPolygon: array of polygons
        case multiPolygon([[[[Double]]]])
    }

    enum CodingKeys: String, CodingKey {
        case type, coordinates
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)

        if type == "MultiPolygon" {
            let raw = try container.decode([[[[Double]]]].self, forKey: .coordinates)
            coordinates = .multiPolygon(raw)
        } else {
            let raw = try container.decode([[[Double]]].self, forKey: .coordinates)
            coordinates = .polygon(raw)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        switch coordinates {
        case .polygon(let rings):
            try container.encode(rings, forKey: .coordinates)
        case .multiPolygon(let polygons):
            try container.encode(polygons, forKey: .coordinates)
        }
    }
}
