//
//  Review.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/17/25.
//


import Foundation

struct Review: Codable {
    let id: String // UUID for the review
    let userId: String // ID of the user who wrote the review
    let profilePhotoUrl: String
    let userFirstName: String
    let userLastName: String
    let placeId: String // ID of the place being reviewed
    let placeName: String // Name of the place
    let foodRating: Double // Food rating (0-10)
    let serviceRating: Double // Service rating (0-10)
    let ambienceRating: Double // Ambience rating (0-10)
    let favoriteDishes: [String] // List of favorite dishes
    let reviewText: String // User's text review
    let timestamp: Date // Time the review was created
    var images: [String] // URLs for uploaded photos (optional)
    var likes: Int // Changed from let to var
}
