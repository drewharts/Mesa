//
//  PlacePost.swift
//  loc
//
//  Simplified post model for place activity feed
//

import Foundation

struct PlacePost: Codable, Identifiable {
    let id: String
    let userId: String
    let profilePhotoUrl: String
    let userFirstName: String
    let userLastName: String
    let placeId: String
    let placeName: String
    let text: String              // Can be empty if only photos
    let timestamp: Date
    var images: [String]          // Can be empty if only text
    var likes: Int
    let wouldReturn: Bool?        // nil = not specified, true = would go back, false = wouldn't revisit
    
    init(id: String, userId: String, profilePhotoUrl: String, userFirstName: String, userLastName: String, placeId: String, placeName: String, text: String, timestamp: Date, images: [String], likes: Int, wouldReturn: Bool? = nil) {
        self.id = id
        self.userId = userId
        self.profilePhotoUrl = profilePhotoUrl
        self.userFirstName = userFirstName
        self.userLastName = userLastName
        self.placeId = placeId
        self.placeName = placeName
        self.text = text
        self.timestamp = timestamp
        self.images = images
        self.likes = likes
        self.wouldReturn = wouldReturn
    }
}

