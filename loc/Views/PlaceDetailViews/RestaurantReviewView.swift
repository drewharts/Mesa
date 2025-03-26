//
//  PlaceReviewView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 3/1/25.
//

import SwiftUI

struct PlaceReviewsView: View {
    @Binding var selectedImage: UIImage?
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let placeId = selectedPlaceVM.selectedPlace?.id.uuidString {
                    let loadingState = selectedPlaceVM.reviewLoadingState(forPlaceId: placeId)
                    let reviews = selectedPlaceVM.reviews // Use view model's reviews
                    
                    switch loadingState {
                    case .loading:
                        ProgressView()
                            .padding()
                            .frame(maxWidth: .infinity)
                        
                    case .loaded:
                        if reviews.isEmpty {
                            Text("No reviews yet.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding()
                        } else {
                            ForEach(reviews, id: \.id) { review in
                                RestaurantReviewView(review: review, selectedImage: $selectedImage)
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                    .background(Color.white)
                                    .cornerRadius(10)
                            }
                        }
                        
                    case .error(let error):
                        Text("Failed to load reviews: \(error.localizedDescription)")
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .padding()
                        
                    case .idle:
                        Text("Reviews not yet loaded")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding()
                    }
                } else {
                    Text("No place selected")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding()
                }
            }
            .frame(maxWidth: .infinity)
            .background(Color.white)
        }
        .background(Color.white)
        .padding(.horizontal, -50)
        .navigationTitle("Reviews")
        .ignoresSafeArea(.all, edges: .all)
    }
}

struct RestaruantReviewViewProfileInformation: View {
    let review: Review
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var profile: ProfileViewModel

    var body: some View {
        HStack(alignment: .center, spacing: 16) { // Increased spacing between photo and text
            // Profile Photo from Cache
            if let profilePhoto = selectedPlaceVM.profilePhoto(forUserId: review.userId) {
                Image(uiImage: profilePhoto)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
            } else if selectedPlaceVM.profilePhotoLoadingState(forUserId: review.userId) == .loading {
                ProgressView()
                    .frame(width: 50, height: 50)
            } else {
                Image(systemName: "person.circle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .foregroundColor(.gray)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("\(review.userFirstName) \(review.userLastName)")
                    .font(.headline)
                    .foregroundColor(.black)

                Text(formattedTimestamp(review.timestamp))
                    .font(.footnote)
                    .foregroundColor(.gray)
                
                // Add likes button and count
                HStack(spacing: 4) {
                    Button(action: {
                        selectedPlaceVM.likeReview(review, userId: profile.userId)
                    }) {
                        Image(systemName: selectedPlaceVM.isReviewLiked(review.id) ? "heart.fill" : "heart")
                            .foregroundColor(review.userId == profile.userId ? .gray : (selectedPlaceVM.isReviewLiked(review.id) ? .red : .gray))
                            .opacity(review.userId == profile.userId ? 0.3 : 0.7)
                    }
                    .disabled(review.userId == profile.userId)
                    
                    Text("\(review.likes)")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.bottom, 15)
    }

    // Helper function to format timestamp
    private func formattedTimestamp(_ date: Date) -> String {
        let now = Date()
        let calendar = Calendar.current
        let daysSince = calendar.dateComponents([.day], from: date, to: now).day ?? 0
        
        // If within 30 days, show number of days
        if daysSince < 30 {
            return daysSince == 0 ? "Today" : "\(daysSince) day\(daysSince == 1 ? "" : "s") ago"
        } else {
            return timestampFormatter.string(from: date)
        }
    }

    private var timestampFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
}

struct RestuarantReviewViewMustOrder: View {
    let review: Review
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            if !review.favoriteDishes.isEmpty {
                Text("Must Order")
                    .font(.caption)
                    .foregroundColor(.black)

                HStack(spacing: 20) {
                    ForEach(review.favoriteDishes, id: \.self) { dish in
                        Button(action: {}) {
                            Text(dish)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 16)
                                .background(Capsule().fill(Color.gray.opacity(0.2)))
                                .foregroundStyle(.black)
                                .font(.caption2)
                        }
                    }
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 30)
        .padding(.bottom, 15)
    }
}

struct RestaurantReviewView: View {
    let review: Review
    @Binding var selectedImage: UIImage?
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel

    var body: some View {
        VStack(spacing: 16) {
            // Header: Profile Picture, Name, and Timestamp
            RestaruantReviewViewProfileInformation(review: review)

            // Ratings (Food, Ambience, Service)
            HStack(spacing: 45) {
                RatingView(title: "Food", score: review.foodRating, color: .green)
                RatingView(title: "Ambience", score: review.ambienceRating, color: .green)
                RatingView(title: "Service", score: review.serviceRating, color: .yellow)
            }
            .padding(.horizontal)
            .padding(.bottom, 15)
            
            // Must Order Section
            RestuarantReviewViewMustOrder(review: review)
            
            // Review Text
            Text(review.reviewText)
                .font(.footnote)
                .foregroundColor(.gray)
                .padding(.horizontal)
                .multilineTextAlignment(.leading)
                .padding(.bottom, 15)
            
            // Images (Horizontal Scrolling) with Loading State
            let reviewPhotos = selectedPlaceVM.photos(for: review)
            let loadingState = selectedPlaceVM.photoLoadingState(for: review)
            
            switch loadingState {
            case .loading:
                ProgressView()
                    .padding(.horizontal)
                    .frame(height: 150) // Match photo height for consistency
                
            case .loaded:
                if !reviewPhotos.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(reviewPhotos, id: \.self) { photo in
                                Image(uiImage: photo)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 150, height: 150)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .onTapGesture {
                                        selectedImage = photo
                                    }
                            }
                        }
                        .padding(.horizontal)
                    }
                } else {
                    Text("No photos available")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                }
                
            case .error(let error):
                Text("Failed to load photos: \(error.localizedDescription)")
                    .font(.footnote)
                    .foregroundColor(.red)
                    .padding(.horizontal)
                
            case .idle:
                Text("Photos not yet loaded")
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
}

struct RatingView: View {
    let title: String
    let score: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 15) {
            Text(title)
                .font(.caption)
                .foregroundColor(.black)

            Text(String(format: "%.1f", score))
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 45, height: 45)
                .background(color)
                .clipShape(Circle())
        }
    }
}

//#Preview {
//    // Sample review data
//    let sampleReviews = [
//        Review(
//            id: "1", // String ID for the review
//            userId: "user1",
//            profilePhotoUrl: "",
//            userFirstName: "John",
//            userLastName: "Doe",
//            placeId: "place1", // String ID for the place
//            placeName: "Italian Bistro",
//            foodRating: 4.5,
//            serviceRating: 3.8,
//            ambienceRating: 4.0,
//            favoriteDishes: ["Pizza", "Pasta"],
//            reviewText: "Great food and vibe, but service could be faster!",
//            timestamp: Date(),
//            images: ["https://example.com/image1.jpg", "https://example.com/image2.jpg"]
//        ),
//        Review(
//            id: "2",
//            userId: "user2",
//            profilePhotoUrl: "",
//            userFirstName: "Jane",
//            userLastName: "Smith",
//            placeId: "place2",
//            placeName: "Cafe Verde",
//            foodRating: 3.0,
//            serviceRating: 4.0,
//            ambienceRating: 4.5,
//            favoriteDishes: ["Salad"],
//            reviewText: "Loved the ambience, food was okay.",
//            timestamp: Date().addingTimeInterval(-86400), // Yesterday
//            images: []
//        )
//    ]
//    
//    // Return the view with sample data
//    PlaceReviewsView(reviews: sampleReviews)
//}

