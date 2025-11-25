import Foundation

struct LightweightPlaceList: Codable, Identifiable {
    let list_id: String
    let name: String
    let is_public: Bool
    let image: String?
    let created_at: String?
    let updated_at: String?
    let distance_meters: Double?
    let place_count: Int
    let city: String?
    
    var id: String { list_id }
    
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
        // Intentionally omitting average_location - we don't need it
    }
}
