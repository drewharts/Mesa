import Foundation

/// Model for followed user photo data returned by the PostgreSQL function
struct FollowedUserPhoto: Identifiable, Codable {
    let userId: String
    let profilePhotoUrl: String?
    
    var id: String { userId }
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case profilePhotoUrl = "profile_photo_url"
    }
}
