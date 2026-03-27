//
//  Comment.swift
//  loc
//
//  Comment on a post/review
//

import Foundation

struct Comment: Codable, Identifiable {
    let id: String
    let reviewId: String
    let userId: String
    let profilePhotoUrl: String
    let userFirstName: String
    let userLastName: String
    let commentText: String
    let timestamp: Date
    var images: [String]
    var likes: Int
    let parentCommentId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case reviewId = "review_id"
        case userId = "user_id"
        case profilePhotoUrl = "profile_photo_url"
        case userFirstName = "user_first_name"
        case userLastName = "user_last_name"
        case commentText = "text"
        case timestamp
        case images
        case likes
        case parentCommentId = "parent_comment_id"
    }
}
