//
//  Review.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/17/25.
//


import Foundation

struct RestaurantReview: ReviewProtocol {
    let id: String
    let userId: String
    let profilePhotoUrl: String
    let userFirstName: String
    let userLastName: String
    let placeId: String
    let placeName: String
    let foodRating: Double
    let serviceRating: Double
    let ambienceRating: Double
    let favoriteDishes: [String]
    let reviewText: String
    let timestamp: Date
    var images: [String]
    var likes: Int
    let type: ReviewType
    
    init(id: String, userId: String, profilePhotoUrl: String, userFirstName: String, userLastName: String, placeId: String, placeName: String, foodRating: Double, serviceRating: Double, ambienceRating: Double, favoriteDishes: [String], reviewText: String, timestamp: Date, images: [String], likes: Int) {
        self.id = id
        self.userId = userId
        self.profilePhotoUrl = profilePhotoUrl
        self.userFirstName = userFirstName
        self.userLastName = userLastName
        self.placeId = placeId
        self.placeName = placeName
        self.foodRating = foodRating
        self.serviceRating = serviceRating
        self.ambienceRating = ambienceRating
        self.favoriteDishes = favoriteDishes
        self.reviewText = reviewText
        self.timestamp = timestamp
        self.images = images
        self.likes = likes
        self.type = .detailed
    }
}
