//
//  GenericReview.swift
//  loc
//
//  Created by Andrew Hartsfield II on 4/11/25.
//

import Foundation

struct GenericReview: ReviewProtocol {
    let id: String
    let userId: String
    let profilePhotoUrl: String
    let userFirstName: String
    let userLastName: String
    let placeId: String
    let placeName: String
    let reviewText: String
    let timestamp: Date
    var images: [String]
    var likes: Int
    let type: ReviewType
    
    init(id: String, userId: String, profilePhotoUrl: String, userFirstName: String, userLastName: String, placeId: String, placeName: String, reviewText: String, timestamp: Date, images: [String], likes: Int) {
        self.id = id
        self.userId = userId
        self.profilePhotoUrl = profilePhotoUrl
        self.userFirstName = userFirstName
        self.userLastName = userLastName
        self.placeId = placeId
        self.placeName = placeName
        self.reviewText = reviewText
        self.timestamp = timestamp
        self.images = images
        self.likes = likes
        self.type = .generic
    }
}
