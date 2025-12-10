//
//  CustomPlaceCreator.swift
//  loc
//
//  Created for custom place creator feature
//

import Foundation

/// Represents the user who created a custom place
/// Used by PlaceDetailView to display "Created by [Name]" for custom places
struct CustomPlaceCreator: Codable, Equatable, Identifiable {
    let userId: String
    let fullName: String
    let profilePhotoUrl: String?
    
    var id: String { userId }
    
    enum CodingKeys: String, CodingKey {
        case userId = "creator_user_id"
        case fullName = "creator_full_name"
        case profilePhotoUrl = "creator_profile_photo_url"
    }
}

