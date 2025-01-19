//
//  PlaceReviewViewModel.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/18/25.
//

import SwiftUI
import Combine
import GooglePlaces

class PlaceReviewViewModel: ObservableObject {
    // MARK: - Published Properties (bound to the View)
    @Published var foodRating: Double = 0
    @Published var serviceRating: Double = 0
    @Published var ambienceRating: Double = 0
    @Published var favoriteDishes: [String] = []
    @Published var reviewText: String = ""
    @Published var images: [UIImage] = []

    // You might track loading & error states for UI feedback:
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Private/Internal
    private let place: GMSPlace
    private let userId: String
    private let userName: String
    private let firestoreService: FirestoreService

    // MARK: - Init
    init(place: GMSPlace,
         userId: String,
         userName: String,
         firestoreService: FirestoreService = FirestoreService()) {
        self.place = place
        self.userId = userId
        self.userName = userName
        self.firestoreService = firestoreService
    }

    // MARK: - Public Methods
    /// Creates a Review object and saves it via FirestoreReviewService
    func submitReview(completion: @escaping (Bool) -> Void) {
        // Mark loading
        isLoading = true
        errorMessage = nil

        // Construct your Review
        let review = Review(
            id: UUID().uuidString,
            userId: userId,
            userName: userName,
            placeId: place.placeID ?? "unknown_place_id",
            placeName: place.name ?? "Unnamed Place",
            foodRating: foodRating,
            serviceRating: serviceRating,
            ambienceRating: ambienceRating,
            favoriteDishes: favoriteDishes,
            reviewText: reviewText,
            timestamp: Date(),
            images: []
        )

        // Call your Firestore service
        firestoreService.saveReview(review) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false

                switch result {
                case .success:
                    completion(true)
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    completion(false)
                }
            }
        }
    }
}

