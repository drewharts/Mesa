//
//  DetailPlace.swift
//  loc
//
//  Created by Andrew Hartsfield II on 2/10/25.
//

import Foundation
import FirebaseFirestore
import MapboxSearch

struct DetailPlace: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var address: String?
    var city: String?
    var mapboxId: String?
    var coordinate: GeoPoint?
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
    
    // Backend-specific fields (ignored by iOS but needed for decoding)
    var googlePlaceId: String?
    var source: String?
    var createdAt: String?
    
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
        case googlePlaceId = "google_place_id"
        case source
        case createdAt = "created_at"
        case photoUrls
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
        self.googlePlaceId = nil
        self.source = nil
        self.createdAt = nil
        
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
        self.userRatingsTotal = try container.decodeIfPresent(Int.self, forKey: .userRatingsTotal)
    }
    
    private mutating func decodeExtendedProperties(from container: KeyedDecodingContainer<CodingKeys>) throws {
        self.openHours = try container.decodeIfPresent([String].self, forKey: .openHours)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.priceLevel = try container.decodeIfPresent(String.self, forKey: .priceLevel)
        self.reservable = try container.decodeIfPresent(Bool.self, forKey: .reservable)
        self.servesBreakfast = try container.decodeIfPresent(Bool.self, forKey: .servesBreakfast)
        self.serversLunch = try container.decodeIfPresent(Bool.self, forKey: .serversLunch)
        self.serversDinner = try container.decodeIfPresent(Bool.self, forKey: .serversDinner)
        self.Instagram = try container.decodeIfPresent(String.self, forKey: .Instagram)
        self.X = try container.decodeIfPresent(String.self, forKey: .X)
    }
    
    private mutating func decodeTikTokProperties(from container: KeyedDecodingContainer<CodingKeys>) throws {
        self.tikTokVideos = try container.decodeIfPresent([TikTokVideo].self, forKey: .tikTokVideos)
        self.googlePlaceId = try container.decodeIfPresent(String.self, forKey: .googlePlaceId)
        self.source = try container.decodeIfPresent(String.self, forKey: .source)
        self.createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        self.photoUrls = try container.decodeIfPresent([String].self, forKey: .photoUrls)
    }
    
    private static func decodeID(from container: KeyedDecodingContainer<CodingKeys>) throws -> UUID {
        let idString = try container.decode(String.self, forKey: .id)
        return UUID(uuidString: idString) ?? UUID()
    }
    
    private static func decodeCoordinates(from container: KeyedDecodingContainer<CodingKeys>) throws -> GeoPoint? {
        // Try backend format first (coordinates object)
        if let coordinatesData = try? container.decode([String: Double].self, forKey: .coordinates),
           let lat = coordinatesData["latitude"], let lng = coordinatesData["longitude"] {
            return GeoPoint(latitude: lat, longitude: lng)
        }
        // Fall back to iOS format (GeoPoint)
        return try container.decodeIfPresent(GeoPoint.self, forKey: .coordinate)
    }
    
    // Custom encoding to maintain compatibility
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id.uuidString, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(address, forKey: .address)
        try container.encodeIfPresent(city, forKey: .city)
        try container.encodeIfPresent(mapboxId, forKey: .mapboxId)
        try container.encodeIfPresent(coordinate, forKey: .coordinate)
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
        try container.encodeIfPresent(googlePlaceId, forKey: .googlePlaceId)
        try container.encodeIfPresent(source, forKey: .source)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(photoUrls, forKey: .photoUrls)
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
        self.googlePlaceId = nil
        self.source = nil
        self.createdAt = nil
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
        self.googlePlaceId = nil
        self.source = nil
        self.createdAt = nil
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
        self.googlePlaceId = nil
        self.source = nil
        self.createdAt = nil
    }

    init(from searchResult: SearchResult) {
        self.id = UUID()
        self.name = searchResult.name
        self.address = searchResult.address?.formattedAddress(style: .medium)
        self.city = searchResult.address?.place
        self.mapboxId = searchResult.id
        self.coordinate = GeoPoint(
            latitude: searchResult.coordinate.latitude,
            longitude: searchResult.coordinate.longitude
        )
        self.categories = searchResult.categories
        self.phone = searchResult.metadata?.phone
        self.rating = searchResult.metadata?.rating
        self.userRatingsTotal = nil
        
        // Handle OpenHours
        if let openHours = searchResult.metadata?.openHours as? OpenHours {
            self.openHours = DetailPlace.serializeOpenHours(openHours)
        } else {
            self.openHours = nil
        }
        
        self.description = searchResult.metadata?.description
        self.priceLevel = searchResult.metadata?.priceLevel
        self.reservable = searchResult.metadata?.reservable
        self.servesBreakfast = searchResult.metadata?.servesBreakfast
        self.serversLunch = searchResult.metadata?.servesLunch
        self.serversDinner = searchResult.metadata?.servesDinner
        self.Instagram = searchResult.metadata?.instagram
        self.X = searchResult.metadata?.twitter
        self.tikTokVideos = nil
        self.photoUrls = nil
        self.googlePlaceId = nil
        self.source = nil
        self.createdAt = nil
    }

    // MARK: - Conversion Methods
    func toPlace() -> Place {
        return Place(
            id: self.id,
            name: self.name,
            address: self.address ?? ""
        )
    }
    
    public static func serializeOpenHours(_ openHours: OpenHours) -> [String] {
        switch openHours {
        case .alwaysOpened:
            return ["always_opened"]
        case .temporarilyClosed:
            return ["temporarily_closed"]
        case .permanentlyClosed:
            return ["permanently_closed"]
        case .scheduled(periods: let periods, weekdayText: let weekdayText, note: let note):
            var result: [String] = periods.map { period in
                // Extract from start and end (DateComponents)
                let open = "\(period.start.weekday ?? 0):\(period.start.hour ?? 0):\(period.start.minute ?? 0)"
                let close = "\(period.end.weekday ?? 0):\(period.end.hour ?? 0):\(period.end.minute ?? 0)"
                return "\(open)-\(close)"
            }
            if let weekdayText = weekdayText {
                result.append(contentsOf: weekdayText)
            }
            if let note = note {
                result.append("note:\(note)")
            }
            return result
        }
    }
}
