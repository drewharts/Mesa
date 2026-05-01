import Foundation
import CoreLocation

struct LightweightPlaceList: Identifiable {
    let list_id: String
    var name: String
    let is_public: Bool
    let image: String?
    let created_at: String?
    let updated_at: String?
    let distance_meters: Double?
    let place_count: Int
    let city: String?
    var description: String?
    var price_tier: String?

    // MARK: - Location Field
    // WKT string from ST_AsText() e.g. "POINT(-73.98 40.76)"
    // Decoder includes GeoJSON fallback for external API boundary safety
    private let average_location_raw: String?

    /// Computed property to parse PostGIS geometry to CLLocationCoordinate2D
    var averageLocation: CLLocationCoordinate2D? {
        guard let raw = average_location_raw else { return nil }
        return Self.parseGeometry(raw)
    }

    // MARK: - Optional Collaboration Fields
    // These are populated when fetching shared lists or lists with collaboration info
    var collaborator_count: Int?
    var is_shared: Bool?
    var owner_name: String?
    var owner_photo_url: String?
    var user_role: String?
    var collaborator_photos: [String]?

    /// Whether this list was saved from another user (not owned by current user)
    var is_saved: Bool?

    var id: String { list_id }

    /// Whether this list requires purchase to access full content
    var isPaid: Bool { price_tier != nil }

    /// Parsed PriceTier enum from the raw string
    var priceTier: PriceTier? {
        guard let price_tier else { return nil }
        return PriceTier(rawValue: price_tier)
    }

    /// Convenience: Check if this list has collaborators
    var hasCollaborators: Bool {
        (collaborator_count ?? 0) > 0
    }

    /// Convenience: Check if this is a shared list (user is not owner)
    var isSharedWithMe: Bool {
        is_shared ?? false
    }

    /// Convenience: Check if this list involves any collaboration
    /// True if: shared with you OR you own it but shared with others
    var isCollaborative: Bool {
        isSharedWithMe || hasCollaborators
    }

    /// Convenience: Check if this is a saved list from another user
    var isSavedList: Bool {
        is_saved ?? false
    }

    // MARK: - Geometry Parsing

    /// Parse PostGIS WKT geometry string to CLLocationCoordinate2D
    /// Pattern: "POINT(longitude latitude)"
    private static func parseGeometry(_ wkt: String) -> CLLocationCoordinate2D? {
        let pattern = #"POINT\(([-\d.]+)\s+([-\d.]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: wkt, range: NSRange(wkt.startIndex..., in: wkt)),
              let lonRange = Range(match.range(at: 1), in: wkt),
              let latRange = Range(match.range(at: 2), in: wkt),
              let lon = Double(wkt[lonRange]),
              let lat = Double(wkt[latRange]) else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    // MARK: - Memberwise Initializer
    init(
        list_id: String,
        name: String,
        is_public: Bool,
        image: String?,
        created_at: String?,
        updated_at: String?,
        distance_meters: Double?,
        place_count: Int,
        city: String?,
        description: String? = nil,
        price_tier: String? = nil,
        average_location_raw: String? = nil,
        collaborator_count: Int? = nil,
        is_shared: Bool? = nil,
        owner_name: String? = nil,
        owner_photo_url: String? = nil,
        user_role: String? = nil,
        collaborator_photos: [String]? = nil,
        is_saved: Bool? = nil
    ) {
        self.list_id = list_id
        self.name = name
        self.is_public = is_public
        self.image = image
        self.created_at = created_at
        self.updated_at = updated_at
        self.distance_meters = distance_meters
        self.place_count = place_count
        self.city = city
        self.description = description
        self.price_tier = price_tier
        self.average_location_raw = average_location_raw
        self.collaborator_count = collaborator_count
        self.is_shared = is_shared
        self.owner_name = owner_name
        self.owner_photo_url = owner_photo_url
        self.user_role = user_role
        self.collaborator_photos = collaborator_photos
        self.is_saved = is_saved
    }
}

// MARK: - Codable Conformance

extension LightweightPlaceList: Codable {
    enum CodingKeys: String, CodingKey {
        case list_id
        case name
        case is_public
        case image
        case created_at
        case updated_at
        case distance_meters
        case place_count
        case city
        case description
        case price_tier
        case average_location
        case collaborator_count
        case is_shared
        case owner_name
        case owner_photo_url
        case user_role
        case collaborator_photos
        case is_saved
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Required fields
        list_id = try container.decode(String.self, forKey: .list_id)
        name = try container.decode(String.self, forKey: .name)
        is_public = try container.decode(Bool.self, forKey: .is_public)
        place_count = try container.decodeIfPresent(Int.self, forKey: .place_count) ?? 0

        // Optional fields
        image = try container.decodeIfPresent(String.self, forKey: .image)
        created_at = try container.decodeIfPresent(String.self, forKey: .created_at)
        updated_at = try container.decodeIfPresent(String.self, forKey: .updated_at)
        distance_meters = try container.decodeIfPresent(Double.self, forKey: .distance_meters)
        city = try container.decodeIfPresent(String.self, forKey: .city)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        price_tier = try container.decodeIfPresent(String.self, forKey: .price_tier)

        // All RPCs return average_location as WKT text via ST_AsText().
        // GeoJSON fallback guards against PostgREST returning raw geometry if an RPC omits ST_AsText().
        do {
            average_location_raw = try container.decodeIfPresent(String.self, forKey: .average_location)
        } catch {
            // Fallback: parse GeoJSON dictionary and convert to WKT
            if let geoJSON = try? container.decodeIfPresent(GeoJSONPoint.self, forKey: .average_location),
               geoJSON.coordinates.count >= 2 {
                average_location_raw = "POINT(\(geoJSON.coordinates[0]) \(geoJSON.coordinates[1]))"
            } else {
                average_location_raw = nil
            }
        }

        // Collaboration fields
        collaborator_count = try container.decodeIfPresent(Int.self, forKey: .collaborator_count)
        is_shared = try container.decodeIfPresent(Bool.self, forKey: .is_shared)
        owner_name = try container.decodeIfPresent(String.self, forKey: .owner_name)
        owner_photo_url = try container.decodeIfPresent(String.self, forKey: .owner_photo_url)
        user_role = try container.decodeIfPresent(String.self, forKey: .user_role)
        collaborator_photos = try container.decodeIfPresent([String].self, forKey: .collaborator_photos)
        is_saved = try container.decodeIfPresent(Bool.self, forKey: .is_saved)
    }

    /// Small Decodable for parsing PostGIS GeoJSON format: {"type":"Point","coordinates":[lon,lat]}
    private struct GeoJSONPoint: Decodable {
        let type: String
        let coordinates: [Double]
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(list_id, forKey: .list_id)
        try container.encode(name, forKey: .name)
        try container.encode(is_public, forKey: .is_public)
        try container.encode(place_count, forKey: .place_count)

        try container.encodeIfPresent(image, forKey: .image)
        try container.encodeIfPresent(created_at, forKey: .created_at)
        try container.encodeIfPresent(updated_at, forKey: .updated_at)
        try container.encodeIfPresent(distance_meters, forKey: .distance_meters)
        try container.encodeIfPresent(city, forKey: .city)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(price_tier, forKey: .price_tier)
        try container.encodeIfPresent(average_location_raw, forKey: .average_location)

        try container.encodeIfPresent(collaborator_count, forKey: .collaborator_count)
        try container.encodeIfPresent(is_shared, forKey: .is_shared)
        try container.encodeIfPresent(owner_name, forKey: .owner_name)
        try container.encodeIfPresent(owner_photo_url, forKey: .owner_photo_url)
        try container.encodeIfPresent(user_role, forKey: .user_role)
        try container.encodeIfPresent(collaborator_photos, forKey: .collaborator_photos)
        try container.encodeIfPresent(is_saved, forKey: .is_saved)
    }
}
