//
//  PlaceReviewView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 3/1/25.
//

import SwiftUI

struct PlaceReviewsView: View {
    let reviews: [Review]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ForEach(reviews, id: \.id) { review in
                    RestaurantReviewView(review: review)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                }
                
                if reviews.isEmpty {
                    Text("No reviews yet.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding()
                }
            }
        }
        .padding(.horizontal,-50)
        .navigationTitle("Reviews")
        .background(Color.white)
    }
}
struct RestaruantReviewViewProfileInformation: View {
    let review: Review
    
    var body: some View {
        Image(systemName: "person.circle.fill")
            .resizable()
            .scaledToFill()
            .frame(width: 50, height: 50)
            .clipShape(Circle())
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(review.userFirstName) \(review.userLastName)")
                    .font(.headline)
                Text(timestampFormatter.string(from: review.timestamp))
                    .font(.footnote)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal)
        .padding(.bottom,15)
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
            Text("Must Order")
                .font(.subheadline)
            
            HStack(spacing: 20) {
                ForEach(review.favoriteDishes, id: \.self) { dish in
                    Button(action: {
                        // Action for the dish (e.g., show details)
                    }) {
                        Text(dish)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 16)
                            .background(Capsule().fill(Color.gray.opacity(0.2)))
                            .foregroundStyle(.black)
                            .font(.footnote)
                    }
                }
                Spacer() // Ensures content stays left-aligned
            }
        }
        .padding(.horizontal,20) // Only pad the right side, keeping left flush
        .padding(.bottom, 15)
    }
}
// Individual Review View (Renamed for clarity, but unchanged internally)
struct RestaurantReviewView: View {
    let review: Review
    
    var body: some View {
        VStack(spacing: 16) {
            // Header: Profile Picture, Name, and Timestamp
            RestaruantReviewViewProfileInformation(review: review)

            // Ratings (Food, Ambience, Service)
            HStack(spacing: 35) {
                RatingView(title: "Food", score: review.foodRating, color: .green)
                RatingView(title: "Ambience", score: review.ambienceRating, color: .green)
                RatingView(title: "Service", score: review.serviceRating, color: .yellow)
            }
            .padding(.horizontal)
            .padding(.bottom,15)
            
            // Must Order Section
            RestuarantReviewViewMustOrder(review: review)
            
            // Review Text
            Text(review.reviewText)
                .font(.body)
                .padding(.horizontal)
                .multilineTextAlignment(.leading)
                .padding(.bottom,15)
            
            // Images
            if !review.images.isEmpty {
                HStack(spacing: 16) {
                    ForEach(review.images.prefix(2), id: \.self) { imageURL in
                        AsyncImage(url: URL(string: imageURL)) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(width: 150, height: 150)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 150, height: 150)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            case .failure:
                                Image(systemName: "photo")
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 150, height: 150)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .foregroundColor(.gray)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
}

// Reusable Rating View (Unchanged)
struct RatingView: View {
    let title: String
    let score: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.footnote)
            Text(String(format: "%.1f", score))
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(color)
                .clipShape(Circle())
        }
    }
}

#Preview {
    // Sample review data
    let sampleReviews = [
        Review(
            id: "1", // String ID for the review
            userId: "user1", // String ID for the user
            userFirstName: "John",
            userLastName: "Doe",
            placeId: "place1", // String ID for the place
            placeName: "Italian Bistro",
            foodRating: 4.5,
            serviceRating: 3.8,
            ambienceRating: 4.0,
            favoriteDishes: ["Pizza", "Pasta"],
            reviewText: "Great food and vibe, but service could be faster!",
            timestamp: Date(),
            images: ["https://example.com/image1.jpg", "https://example.com/image2.jpg"]
        ),
        Review(
            id: "2",
            userId: "user2",
            userFirstName: "Jane",
            userLastName: "Smith",
            placeId: "place2",
            placeName: "Cafe Verde",
            foodRating: 3.0,
            serviceRating: 4.0,
            ambienceRating: 4.5,
            favoriteDishes: ["Salad"],
            reviewText: "Loved the ambience, food was okay.",
            timestamp: Date().addingTimeInterval(-86400), // Yesterday
            images: []
        )
    ]
    
    // Return the view with sample data
    PlaceReviewsView(reviews: sampleReviews)
}

