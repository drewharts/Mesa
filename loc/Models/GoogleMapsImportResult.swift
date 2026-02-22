//
//  GoogleMapsImportResult.swift
//  loc
//
//  Model: Response data from the Google Maps list import backend endpoints
//  Single Responsibility: Decode JSON responses for Google Maps import flow
//

import Foundation

// MARK: - Legacy Single-Request Import (POST /maps/import-list)

/// Decoded response from the /maps/import-list backend endpoint.
struct GoogleMapsImportResult: Codable {
    let listName: String
    let places: [ImportedPlace]
    let totalExtracted: Int
    let totalResolved: Int
    let errors: [String]

    enum CodingKeys: String, CodingKey {
        case listName = "list_name"
        case places
        case totalExtracted = "total_extracted"
        case totalResolved = "total_resolved"
        case errors
    }
}

/// A single place resolved by the backend during Google Maps list import.
struct ImportedPlace: Codable, Identifiable {
    let id: String
    let name: String
    let address: String
    let googlePlacesId: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case address
        case googlePlacesId = "google_places_id"
    }
}

// MARK: - Two-Phase Import (POST /maps/extract-list + POST /maps/resolve-place)

/// Decoded response from the /maps/extract-list endpoint (Phase 1: extraction only).
struct GoogleMapsExtractResult: Codable {
    let listName: String
    let places: [ExtractedPlace]
    let totalExtracted: Int

    enum CodingKeys: String, CodingKey {
        case listName = "list_name"
        case places
        case totalExtracted = "total_extracted"
    }
}

/// A raw place extracted from a Google Maps list before Serper resolution.
struct ExtractedPlace: Codable, Identifiable {
    let name: String?
    let latitude: Double
    let longitude: Double
    let address: String?

    /// Synthesized identity from coordinates and name for SwiftUI list rendering.
    var id: String {
        "\(latitude),\(longitude)-\(name ?? "")"
    }
}

/// Decoded response from the /maps/resolve-place endpoint (Phase 2: single-place resolution).
struct GoogleMapsResolveResult: Codable {
    let resolved: Bool
    let place: ImportedPlace?
    let error: String?
}
