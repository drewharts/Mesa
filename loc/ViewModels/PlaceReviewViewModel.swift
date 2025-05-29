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
       print("🎯 Starting review submission process")
       // Create the review object first
       let timestamp = Date()
       let reviewId = UUID().uuidString
       print("📝 Generated review ID: \(reviewId)")
       
       if reviewType == .restaurant {
           print("🍽️ Creating restaurant review")
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
           
           print("🔄 Calling saveReviewWithImages for restaurant review")
           // Use the saveReviewWithImages method to handle both image upload and review saving
           firestoreService.saveReviewWithImages(review: review, images: images) { result in
               switch result {
               case .success(let savedReview):
                   print("✅ Successfully saved restaurant review")
                   completion(.success(savedReview))
               case .failure(let error):
                   print("❌ Error saving restaurant review: \(error.localizedDescription)")
                   completion(.failure(error))
               }
           }
       } else {
           print("📝 Creating generic review")
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
           
           print("🔄 Calling saveReviewWithImages for generic review")
           // Use the saveReviewWithImages method to handle both image upload and review saving
           firestoreService.saveReviewWithImages(review: review, images: images) { result in
               switch result {
               case .success(let savedReview):
                   print("✅ Successfully saved generic review")
                   completion(.success(savedReview))
               case .failure(let error):
                   print("❌ Error saving generic review: \(error.localizedDescription)")
                   completion(.failure(error))
               }
           }
       }
   }

   func deleteReview(reviewId: String, completion: @escaping (Result<Void, Error>) -> Void) {
       print("🗑️ Starting review deletion process for ID: \(reviewId)")
       isLoading = true
       errorMessage = nil
       
       firestoreService.deleteReview(reviewId: reviewId, placeId: place.id.uuidString, userId: userId) { [weak self] result in
           DispatchQueue.main.async {
               self?.isLoading = false
               
               switch result {
               case .success:
                   print("✅ Successfully deleted review with ID: \(reviewId)")
                   completion(.success(()))
               case .failure(let error):
                   print("❌ Error deleting review: \(error.localizedDescription)")
                   self?.errorMessage = "Failed to delete review: \(error.localizedDescription)"
                   completion(.failure(error))
               }
           }
       }
   }
}

