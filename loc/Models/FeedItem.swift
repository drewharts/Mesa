//
//  FeedItem.swift
//  loc
//
//  Model representing a single photo feed item from a followed user's review.
//

import Foundation

struct FeedItem: Codable, Identifiable {
    let id: String
    let userId: String
    let userFirstName: String
    let userLastName: String
    let profilePhotoUrl: String
    let placeId: String
    let placeName: String
    let caption: String
    let imageUrls: [String]
    let timestamp: Date
    var likes: Int
    var commentCount: Int
    let wouldReturn: Bool?
    let latitude: Double
    let longitude: Double
}
