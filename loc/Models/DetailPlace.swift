//
//  DetailPlace.swift
//  loc
//
//  Created by Andrew Hartsfield II on 2/10/25.
//

import Foundation
import CoreLocation

struct DetailPlace: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var address: String?
    var city: String?
    var mapboxId: String?
    var coordinate: CLLocationCoordinate2D?
    var categories: [String]?
    var phone: String?
    var rating: Double?
    var userRatingsTotal: Int?
    var openHours: [String]?
    var description: String?
    var priceLevel: String?
    var reservable: Bool?
    var servesBreakfast: Bool?
    var serversLunch: Bool?
    var serversDinner: Bool?
    var Instagram: String?
    var X: String?
    var tikTokVideos: [TikTokVideo]?
    var photoUrls: [String]? = []
    var menuUrl: String?
    var websiteUrl: String?

    // AI suggestion field - explains why AI recommended this place
    var aiSuggestionReason: String?

    // Backend-specific fields (ignored by iOS but needed for decoding)
    var googlePlaceId: String?
    var source: String?
    var createdAt: String?
    var isCustom: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case address
        case city
        case mapboxId
        case coordinate
        case coordinates  // Backend uses "coordinates" plural
        case categories
        case phone
        case rating
        case userRatingsTotal = "user_ratings_total"
        case ratingCount  // Legacy field name "ratingCount"
        case openHours
        case description
        case priceLevel
        case reservable
        case servesBreakfast
        case serversLunch
        case serversDinner
        case Instagram
        case X
        case tikTokVideos = "tiktok_videos"
        case menuUrl = "menu_url"
        case websiteUrl = "website"
        case googlePlaceId = "google_place_id"
        case googlePlacesId  // Legacy field name "googlePlacesId" (with 's')
        case source
        case createdAt = "created_at"
        case photoUrls
        case thumbnailUrl  // Legacy field name "thumbnailUrl"
        case isCustom = "is_custom"
        case aiSuggestionReason
    }
    
    // Custom decoding to handle backend's coordinates format
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Initialize required properties first
        self.id = try Self.decodeID(from: container)
        self.name = try container.decode(String.self, forKey: .name)
        
        // Initialize all optional properties to nil first
        self.address = nil
        self.city = nil
        self.mapboxId = nil
        self.coordinate = nil
        self.categories = nil
        self.phone = nil
        self.rating = nil
        self.userRatingsTotal = nil
        self.openHours = nil
        self.description = nil
        self.priceLevel = nil
        self.reservable = nil
        self.servesBreakfast = nil
        self.serversLunch = nil
        self.serversDinner = nil
        self.Instagram = nil
        self.X = nil
        self.tikTokVideos = nil
        self.photoUrls = nil
        self.menuUrl = nil
        self.websiteUrl = nil
        self.googlePlaceId = nil
        self.source = nil
        self.createdAt = nil
        self.isCustom = nil
        self.aiSuggestionReason = nil

        // Now decode all the optional properties
        try decodeBasicProperties(from: container)
        try decodeExtendedProperties(from: container)
        try decodeTikTokProperties(from: container)
        self.coordinate = try Self.decodeCoordinates(from: container)
    }
    
    private mutating func decodeBasicProperties(from container: KeyedDecodingContainer<CodingKeys>) throws {
        self.address = try container.decodeIfPresent(String.self, forKey: .address)
        self.city = try container.decodeIfPresent(String.self, forKey: .city)
        self.mapboxId = try container.decodeIfPresent(String.self, forKey: .mapboxId)
        self.categories = try container.decodeIfPresent([String].self, forKey: .categories)
        self.phone = try container.decodeIfPresent(String.self, forKey: .phone)
        self.rating = try container.decodeIfPresent(Double.self, forKey: .rating)
        
        // Try both field names for rating count (backend uses user_ratings_total, legacy uses ratingCount)
        self.userRatingsTotal = try container.decodeIfPresent(Int.self, forKey: .userRatingsTotal) 
            ?? container.decodeIfPresent(Int.self, forKey: .ratingCount)
    }
    
    private mutating func decodeExtendedProperties(from container: KeyedDecodingContainer<CodingKeys>) throws {
        // Try to decode openHours as array of strings first (backend format)
        self.openHours = try? container.decodeIfPresent([String].self, forKey: .openHours)
        
        // If that fails, try to decode as array of objects (legacy format)
        if self.openHours == nil {
            if let openHoursObjects = try? container.decodeIfPresent([[String: String]].self, forKey: .openHours) {
                // Convert from [{ day: "Monday", hours: "11 AM–11 PM" }] to ["Monday: 11 AM–11 PM"]
                self.openHours = openHoursObjects.compactMap { dict in
                    guard let day = dict["day"], let hours = dict["hours"] else { return nil }
                    return "\(day): \(hours)"
                }
            }
        }
        
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.priceLevel = try container.decodeIfPresent(String.self, forKey: .priceLevel)
        self.reservable = try container.decodeIfPresent(Bool.self, forKey: .reservable)
        self.servesBreakfast = try container.decodeIfPresent(Bool.self, forKey: .servesBreakfast)
        self.serversLunch = try container.decodeIfPresent(Bool.self, forKey: .serversLunch)
        self.serversDinner = try container.decodeIfPresent(Bool.self, forKey: .serversDinner)
        self.Instagram = try container.decodeIfPresent(String.self, forKey: .Instagram)
        self.X = try container.decodeIfPresent(String.self, forKey: .X)
        self.menuUrl = try container.decodeIfPresent(String.self, forKey: .menuUrl)
        self.websiteUrl = try container.decodeIfPresent(String.self, forKey: .websiteUrl)
    }

    private mutating func decodeTikTokProperties(from container: KeyedDecodingContainer<CodingKeys>) throws {
        self.tikTokVideos = try container.decodeIfPresent([TikTokVideo].self, forKey: .tikTokVideos)
        
        // Try both field names for Google Place ID (backend uses google_place_id, legacy uses googlePlacesId)
        let googlePlaceIdBackend = try container.decodeIfPresent(String.self, forKey: .googlePlaceId)
        let googlePlaceIdLegacy = try container.decodeIfPresent(String.self, forKey: .googlePlacesId)

        self.googlePlaceId = googlePlaceIdBackend ?? googlePlaceIdLegacy
        
        self.source = try container.decodeIfPresent(String.self, forKey: .source)
        
        // If source is nil, infer it from which external ID exists
        if self.source == nil {
            if self.googlePlaceId != nil && !self.googlePlaceId!.isEmpty {
                self.source = "google"
            } else if self.mapboxId != nil && !self.mapboxId!.isEmpty {
                self.source = "mapbox"
            }
        }
        
        self.createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        self.isCustom = try container.decodeIfPresent(Bool.self, forKey: .isCustom)
        
        // Try to decode photoUrls, or use thumbnailUrl as fallback
        self.photoUrls = try container.decodeIfPresent([String].self, forKey: .photoUrls)
        if self.photoUrls == nil || self.photoUrls?.isEmpty == true {
            if let thumbnailUrl = try container.decodeIfPresent(String.self, forKey: .thumbnailUrl) {
                self.photoUrls = [thumbnailUrl]
            }
        }

        // Decode AI suggestion reason (from AI search endpoint)
        self.aiSuggestionReason = try container.decodeIfPresent(String.self, forKey: .aiSuggestionReason)
    }
    
    private static func decodeID(from container: KeyedDecodingContainer<CodingKeys>) throws -> UUID {
        let idString = try container.decode(String.self, forKey: .id)
        return UUID(uuidString: idString) ?? UUID()
    }
    
    private static func decodeCoordinates(from container: KeyedDecodingContainer<CodingKeys>) throws -> CLLocationCoordinate2D? {
        // Try backend format first (coordinates object with lat/lng)
        if let coordinatesData = try? container.decode([String: Double].self, forKey: .coordinates),
           let lat = coordinatesData["latitude"], let lng = coordinatesData["longitude"] {
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
        
        // Try to decode as a structure with latitude and longitude
        if let coordData = try? container.decodeIfPresent([String: Double].self, forKey: .coordinate),
           let lat = coordData["latitude"], let lng = coordData["longitude"] {
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
        
        return nil
    }
    
    // Custom encoding to maintain compatibility
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id.uuidString, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(address, forKey: .address)
        try container.encodeIfPresent(city, forKey: .city)
        try container.encodeIfPresent(mapboxId, forKey: .mapboxId)
        // Encode coordinate as dictionary for Supabase compatibility
        if let coordinate = coordinate {
            let coordDict = ["latitude": coordinate.latitude, "longitude": coordinate.longitude]
            try container.encode(coordDict, forKey: .coordinate)
        }
        try container.encodeIfPresent(categories, forKey: .categories)
        try container.encodeIfPresent(phone, forKey: .phone)
        try container.encodeIfPresent(rating, forKey: .rating)
        try container.encodeIfPresent(userRatingsTotal, forKey: .userRatingsTotal)
        try container.encodeIfPresent(openHours, forKey: .openHours)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(priceLevel, forKey: .priceLevel)
        try container.encodeIfPresent(reservable, forKey: .reservable)
        try container.encodeIfPresent(servesBreakfast, forKey: .servesBreakfast)
        try container.encodeIfPresent(serversLunch, forKey: .serversLunch)
        try container.encodeIfPresent(serversDinner, forKey: .serversDinner)
        try container.encodeIfPresent(Instagram, forKey: .Instagram)
        try container.encodeIfPresent(X, forKey: .X)
        try container.encodeIfPresent(tikTokVideos, forKey: .tikTokVideos)
        try container.encodeIfPresent(menuUrl, forKey: .menuUrl)
        try container.encodeIfPresent(websiteUrl, forKey: .websiteUrl)
        try container.encodeIfPresent(googlePlaceId, forKey: .googlePlaceId)
        try container.encodeIfPresent(source, forKey: .source)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(photoUrls, forKey: .photoUrls)
        try container.encodeIfPresent(isCustom, forKey: .isCustom)
        try container.encodeIfPresent(aiSuggestionReason, forKey: .aiSuggestionReason)
    }

    // Existing initializers unchanged
    init() {
        self.id = UUID()
        self.name = ""
        self.address = nil
        self.mapboxId = nil
        self.coordinate = nil
        self.categories = nil
        self.phone = nil
        self.rating = nil
        self.userRatingsTotal = nil
        self.openHours = nil
        self.description = nil
        self.priceLevel = nil
        self.reservable = nil
        self.servesBreakfast = nil
        self.serversLunch = nil
        self.serversDinner = nil
        self.Instagram = nil
        self.X = nil
        self.tikTokVideos = nil
        self.photoUrls = nil
        self.menuUrl = nil
        self.websiteUrl = nil
        self.googlePlaceId = nil
        self.source = nil
        self.createdAt = nil
        self.isCustom = nil
        self.aiSuggestionReason = nil
    }

    init(place: Place) {
        self.id = place.id
        self.name = place.name
        self.address = place.address
        self.mapboxId = nil
        self.coordinate = nil
        self.categories = nil
        self.phone = nil
        self.rating = nil
        self.userRatingsTotal = nil
        self.openHours = nil
        self.description = nil
        self.priceLevel = nil
        self.reservable = nil
        self.servesBreakfast = nil
        self.serversLunch = nil
        self.serversDinner = nil
        self.Instagram = nil
        self.X = nil
        self.tikTokVideos = nil
        self.photoUrls = nil
        self.menuUrl = nil
        self.websiteUrl = nil
        self.googlePlaceId = nil
        self.source = nil
        self.createdAt = nil
        self.isCustom = nil
        self.aiSuggestionReason = nil
    }

    init(id: UUID, name: String, address: String?, city: String?) {
        self.id = id
        self.name = name
        self.address = address
        self.city = city
        self.mapboxId = nil
        self.coordinate = nil
        self.categories = nil
        self.phone = nil
        self.rating = nil
        self.userRatingsTotal = nil
        self.openHours = nil
        self.description = nil
        self.priceLevel = nil
        self.reservable = nil
        self.servesBreakfast = nil
        self.serversLunch = nil
        self.serversDinner = nil
        self.Instagram = nil
        self.X = nil
        self.tikTokVideos = nil
        self.photoUrls = nil
        self.menuUrl = nil
        self.websiteUrl = nil
        self.googlePlaceId = nil
        self.source = nil
        self.createdAt = nil
        self.isCustom = nil
        self.aiSuggestionReason = nil
    }

    // Removed MapboxSearch SearchResult initializer - now using Google Places API

    // MARK: - Conversion Methods
    func toPlace() -> Place {
        return Place(
            id: self.id,
            name: self.name,
            address: self.address ?? ""
        )
    }
    
    // Removed MapboxSearch OpenHours serialization - now using Google Places API
}

// MARK: - LightweightPlace Conversion

extension DetailPlace {
    /// Convert to LightweightPlace for use in grid tiles
    /// Uses first photo URL as latest_review_photo for consistency with other popups
    var asLightweightPlace: LightweightPlace {
        LightweightPlace(
            place_id: id.uuidString,
            name: name,
            latest_review_photo: photoUrls?.first
        )
    }
}
