//
//  PlaceReviewViewModel.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/18/25.
//

import SwiftUI
import Combine
import MapboxSearch

class PlaceReviewViewModel: ObservableObject {
    // MARK: - Published Properties (bound to the View)
    @Published var foodRating: Double = 0
    @Published var serviceRating: Double = 0
    @Published var ambienceRating: Double = 0
    @Published var favoriteDishes: [String] = []
    @Published var reviewText: String = ""
    @Published var images: [UIImage] = []
    @Published var reviewType: CreatePlaceReviewView.ReviewType = .restaurant

    // You might track loading & error states for UI feedback:
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? 

    // MARK: - Private/Internal
    private let place: DetailPlace
    private let userId: String
    private let userFirstName: String
    private let userLastName: String
    private let profilePhotoUrl: String
    private let firestoreService: FirestoreService

    // MARK: - Init
    init(place: DetailPlace,
         userId: String,
         userFirstName: String,
         userLastName: String,
         profilePhotoUrl: String,
         firestoreService: FirestoreService = FirestoreService()) {
        self.place = place
        self.userId = userId
        self.userFirstName = userFirstName
        self.userLastName = userLastName
        self.profilePhotoUrl = profilePhotoUrl
        self.firestoreService = firestoreService
    }

    func submitReview(completion: @escaping (Result<any ReviewProtocol, Error>) -> Void) {
        // Create the review object first
        let timestamp = Date()
        let reviewId = UUID().uuidString
        
        if reviewType == .restaurant {
            let review = RestaurantReview(
                id: reviewId,
                userId: userId,
                profilePhotoUrl: profilePhotoUrl,
                userFirstName: userFirstName,
                userLastName: userLastName,
                placeId: place.id.uuidString,
                placeName: place.name ?? "Unnamed Place",
                foodRating: foodRating,
                serviceRating: serviceRating,
                ambienceRating: ambienceRating,
                favoriteDishes: favoriteDishes,
                reviewText: reviewText,
                timestamp: timestamp,
                images: [], // Will be updated by saveReviewWithImages
                likes: 0
            )
            
            // Use the saveReviewWithImages method to handle both image upload and review saving
            firestoreService.saveReviewWithImages(review: review, images: images) { result in
                switch result {
                case .success(let savedReview):
                    completion(.success(savedReview))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        } else {
            let review = GenericReview(
                id: reviewId,
                userId: userId,
                profilePhotoUrl: profilePhotoUrl,
                userFirstName: userFirstName,
                userLastName: userLastName,
                placeId: place.id.uuidString,
                placeName: place.name ?? "Unnamed Place",
                reviewText: reviewText,
                timestamp: timestamp,
                images: [], // Will be updated by saveReviewWithImages
                likes: 0
            )
            
            // Use the saveReviewWithImages method to handle both image upload and review saving
            firestoreService.saveReviewWithImages(review: review, images: images) { result in
                switch result {
                case .success(let savedReview):
                    completion(.success(savedReview))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
}

