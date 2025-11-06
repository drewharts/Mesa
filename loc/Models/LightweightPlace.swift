import Foundation

/// Lightweight place data for tiles (used for both place list items and my places)
struct LightweightPlace: Codable, Identifiable {
    let place_id: String
    let name: String
    let latest_review_photo: String?
    let external_place_id: String? // UUID from external_places table (row ID, unique per TikTok video)
    let tiktok_url: String? // TikTok video URL from external_places table
    
    var id: String { place_id }
    
    enum CodingKeys: String, CodingKey {
        case place_id
        case name
        case latest_review_photo
        case external_place_id
        case tiktok_url
        // Intentionally omitting coordinate - we don't need it for tiles
    }
}
