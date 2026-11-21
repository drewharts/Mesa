import Foundation

/// Lightweight place data for tiles (used for both place list items and my places)
/// Single Responsibility: Represent minimal place data for efficient list display
struct LightweightPlace: Codable, Identifiable, Equatable {
    let place_id: String
    let name: String
    let latitude: Double?
    let longitude: Double?
    let latest_review_photo: String?
    let external_place_id: String? // UUID from external_places table (row ID, unique per external video)
    let content_url: String? // External video URL from external_places table
    let place_type: String? // Primary category (e.g. "restaurant", "cafe")
    let thumbnail_url: String? // Google Places thumbnail — last-resort fallback for images
    let categories: [String]? // Full raw category list (Google types and/or human labels); only set for list places
    let user_corrected_category: String? // Category the user corrected; wins over `categories` for tags

    // MARK: - Added By Info (for collaborative lists)
    // These fields are only populated when fetching places from a collaborative list
    // For personal lists, these will be nil (no need to show "added by" for single-user lists)
    let added_by_user_id: String?
    let added_by_name: String?
    let added_by_photo_url: String?

    var id: String { place_id }

    /// Hides junk names written by a bad enrichment result (literal "undefined"/"null"/blank).
    /// Case-sensitive on purpose: "Undefined" is a real restaurant name.
    static func displayName(_ name: String, address: String? = nil) -> String {
        let t = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.isEmpty || t == "undefined" || t == "null" else { return t }
        let first = address?.split(separator: ",").first.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
        return first.isEmpty ? "Unnamed place" : first
    }

    enum CodingKeys: String, CodingKey {
        case place_id
        case name
        case latitude
        case longitude
        case latest_review_photo
        case external_place_id
        case content_url = "tiktok_url"
        case place_type
        case thumbnail_url
        case categories
        case user_corrected_category
        case added_by_user_id
        case added_by_name
        case added_by_photo_url
    }

    // MARK: - Convenience Initializer for Backward Compatibility

    init(
        place_id: String,
        name: String,
        latitude: Double? = nil,
        longitude: Double? = nil,
        latest_review_photo: String?,
        external_place_id: String? = nil,
        content_url: String? = nil,
        place_type: String? = nil,
        thumbnail_url: String? = nil,
        added_by_user_id: String? = nil,
        added_by_name: String? = nil,
        added_by_photo_url: String? = nil,
        categories: [String]? = nil,
        user_corrected_category: String? = nil
    ) {
        self.place_id = place_id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.latest_review_photo = latest_review_photo
        self.external_place_id = external_place_id
        self.content_url = content_url
        self.place_type = place_type
        self.thumbnail_url = thumbnail_url
        self.added_by_user_id = added_by_user_id
        self.added_by_name = added_by_name
        self.added_by_photo_url = added_by_photo_url
        self.categories = categories
        self.user_corrected_category = user_corrected_category
    }

    /// Copy of this place carrying the given raw categories and user-corrected category.
    func withCategories(_ categories: [String]?, userCorrectedCategory: String?) -> LightweightPlace {
        LightweightPlace(
            place_id: place_id, name: name, latitude: latitude, longitude: longitude,
            latest_review_photo: latest_review_photo, external_place_id: external_place_id,
            content_url: content_url, place_type: place_type, thumbnail_url: thumbnail_url,
            added_by_user_id: added_by_user_id, added_by_name: added_by_name,
            added_by_photo_url: added_by_photo_url,
            categories: categories, user_corrected_category: userCorrectedCategory
        )
    }
}
