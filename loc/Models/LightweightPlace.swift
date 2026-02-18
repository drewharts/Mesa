import Foundation

/// Lightweight place data for tiles (used for both place list items and my places)
/// Single Responsibility: Represent minimal place data for efficient list display
struct LightweightPlace: Codable, Identifiable, Equatable {
    let place_id: String
    let name: String
    let latitude: Double?
    let longitude: Double?
    let latest_review_photo: String?
    let external_place_id: String? // UUID from external_places table (row ID, unique per TikTok video)
    let tiktok_url: String? // TikTok video URL from external_places table

    // MARK: - Added By Info (for collaborative lists)
    // These fields are only populated when fetching places from a collaborative list
    // For personal lists, these will be nil (no need to show "added by" for single-user lists)
    let added_by_user_id: String?
    let added_by_name: String?
    let added_by_photo_url: String?
    
    var id: String { place_id }
    
    enum CodingKeys: String, CodingKey {
        case place_id
        case name
        case latitude
        case longitude
        case latest_review_photo
        case external_place_id
        case tiktok_url
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
        tiktok_url: String? = nil,
        added_by_user_id: String? = nil,
        added_by_name: String? = nil,
        added_by_photo_url: String? = nil
    ) {
        self.place_id = place_id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.latest_review_photo = latest_review_photo
        self.external_place_id = external_place_id
        self.tiktok_url = tiktok_url
        self.added_by_user_id = added_by_user_id
        self.added_by_name = added_by_name
        self.added_by_photo_url = added_by_photo_url
    }
}
