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
   private let reviewService: ReviewService
   private let imageService: ImageService

   // MARK: - Init
   init(place: DetailPlace,
        userId: String,
        userFirstName: String,
        userLastName: String,
        profilePhotoUrl: String,
        reviewService: ReviewService = .shared,
        imageService: ImageService = .shared) {
       self.place = place
       self.userId = userId
       self.userFirstName = userFirstName
       self.userLastName = userLastName
       self.profilePhotoUrl = profilePhotoUrl
       self.reviewService = reviewService
       self.imageService = imageService
   }

   func submitReview(completion: @escaping (Result<any ReviewProtocol, Error>) -> Void) {
       print("🎯 Starting review submission process")
       isLoading = true
       errorMessage = nil

       // Create the review object first
       let timestamp = Date()
       let reviewId = UUID().uuidString
       print("📝 Generated review ID: \(reviewId)")

       var review: any ReviewProtocol

       if reviewType == .restaurant {
           print("🍽️ Creating restaurant review")
           review = RestaurantReview(
               id: reviewId,
               userId: userId,
               profilePhotoUrl: profilePhotoUrl,
               userFirstName: userFirstName,
               userLastName: userLastName,
               placeId: place.id.uuidString,
               placeName: place.name,
               foodRating: foodRating,
               serviceRating: serviceRating,
               ambienceRating: ambienceRating,
               favoriteDishes: favoriteDishes,
               reviewText: reviewText,
               timestamp: timestamp,
               images: [], // Will be populated after upload
               likes: 0
           )
       } else {
           print("📝 Creating generic review")
           review = GenericReview(
               id: reviewId,
               userId: userId,
               profilePhotoUrl: profilePhotoUrl,
               userFirstName: userFirstName,
               userLastName: userLastName,
               placeId: place.id.uuidString,
               placeName: place.name,
               reviewText: reviewText,
               timestamp: timestamp,
               images: [], // Will be populated after upload
               likes: 0
           )
       }

       // If there are images, upload them first
       if !images.isEmpty {
           print("🖼️ Starting image upload...")
           imageService.uploadImagesForReview(review: review, images: images) { [weak self] result in
               guard let self = self else { return }

               switch result {
               case .success(let imageUrls):
                   print("✅ Image upload successful")
                   var mutableReview = review
                   mutableReview.images = imageUrls
                   self.saveReview(mutableReview, completion: completion)
               case .failure(let error):
                   print("❌ Image upload failed: \(error.localizedDescription)")
                   DispatchQueue.main.async {
                       self.isLoading = false
                       self.errorMessage = "Failed to upload images: \(error.localizedDescription)"
                       completion(.failure(error))
                   }
               }
           }
       } else {
           // If no images, just save the review
           print("ℹ️ No images to upload, saving review directly.")
           saveReview(review, completion: completion)
       }
   }

   private func saveReview(_ review: any ReviewProtocol, completion: @escaping (Result<any ReviewProtocol, Error>) -> Void) {
       print("🔄 Saving review...")
       reviewService.saveReview(review) { [weak self] result in
           DispatchQueue.main.async {
               self?.isLoading = false
               switch result {
               case .success:
                   print("✅ Successfully saved review")
                   completion(.success(review))
               case .failure(let error):
                   print("❌ Error saving review: \(error.localizedDescription)")
                   self?.errorMessage = "Failed to save review: \(error.localizedDescription)"
                   completion(.failure(error))
               }
           }
       }
   }

   func deleteReview(reviewId: String, completion: @escaping (Result<Void, Error>) -> Void) {
       print("🗑️ Starting review deletion process for ID: \(reviewId)")
       isLoading = true
       errorMessage = nil
       
       reviewService.deleteReview(reviewId: reviewId, placeId: place.id.uuidString, userId: userId) { [weak self] result in
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

