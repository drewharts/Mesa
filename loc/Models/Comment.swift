//
//  Comment.swift
//  loc
//
//  Created by Andrew Hartsfield II on 4/4/25.
//

import Foundation

struct Comment: Codable, Identifiable {
    let id: String // UUID for the comment
    let reviewId: String // ID of the review this comment belongs to
    let userId: String // ID of the user who wrote the comment
    let profilePhotoUrl: String
    let userFirstName: String
    let userLastName: String
    let commentText: String // User's comment text
    let timestamp: Date // Time the comment was created
    var images: [String] // URLs for uploaded photos (optional)
    var likes: Int // Number of likes on the comment
}
