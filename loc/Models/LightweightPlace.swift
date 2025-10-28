import Foundation

/// Lightweight place data for tiles (used for both place list items and my places)
struct LightweightPlace: Codable, Identifiable {
    let place_id: String
    let name: String
    let latest_review_photo: String?
    
    var id: String { place_id }
    
    enum CodingKeys: String, CodingKey {
        case place_id
        case name
        case latest_review_photo
        // Intentionally omitting coordinate - we don't need it for tiles
    }
}
