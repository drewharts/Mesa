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
    var collaborator_count: Int?
    var is_shared: Bool?
    var owner_name: String?
    var user_role: String?
    
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
    
    // MARK: - Custom Initializer with Defaults
    // Provides backward compatibility for existing code
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
        collaborator_count: Int? = nil,
        is_shared: Bool? = nil,
        owner_name: String? = nil,
        user_role: String? = nil
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
        self.collaborator_count = collaborator_count
        self.is_shared = is_shared
        self.owner_name = owner_name
        self.user_role = user_role
    }
}
