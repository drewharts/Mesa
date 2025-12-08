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
    
    // MARK: - Optional Collaboration Fields
    // These are populated when fetching shared lists or lists with collaboration info
    let collaborator_count: Int?
    let is_shared: Bool?
    let owner_name: String?
    let user_role: String?
    
    var id: String { list_id }
    
    /// Convenience: Check if this list has collaborators
    var hasCollaborators: Bool {
        (collaborator_count ?? 0) > 0
    }
    
    /// Convenience: Check if this is a shared list (user is not owner)
    var isSharedWithMe: Bool {
        is_shared ?? false
    }
    
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
        case collaborator_count
        case is_shared
        case owner_name
        case user_role
        // Intentionally omitting average_location - we don't need it
    }
}
