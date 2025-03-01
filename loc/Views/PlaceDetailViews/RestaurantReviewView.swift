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
                        .shadow(radius: 2)
                }
                
                if reviews.isEmpty {
                    Text("No reviews yet.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding()
                }
            }
        }
        .navigationTitle("Reviews")
    }
}

// Individual Review View (Renamed for clarity, but unchanged internally)
struct RestaurantReviewView: View {
    let review: Review
    
    var body: some View {
        VStack(spacing: 16) {
            // Header: Profile Picture, Name, and Timestamp
            HStack(spacing: 12) {
                // Placeholder for profile image (you might want to fetch this dynamically or use a default image)
                Image(systemName: "person.circle.fill") // Default profile icon
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.blue, lineWidth: 2))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(review.userFirstName) \(review.userLastName)")
                        .font(.headline)
                    Text(timestampFormatter.string(from: review.timestamp))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                Spacer()
            }
            .padding(.horizontal)
            
            // Ratings (Food, Ambience, Service)
            HStack(spacing: 20) {
                RatingView(title: "Food", score: review.foodRating, color: .green)
                RatingView(title: "Ambience", score: review.ambienceRating, color: .green)
                RatingView(title: "Service", score: review.serviceRating, color: .yellow)
            }
            .padding(.horizontal)
            
            // Must Order Section (Using favoriteDishes from the model)
            VStack(alignment: .leading, spacing: 8) {
                Text("Must Order")
                    .font(.headline)
                
                HStack(spacing: 8) {
                    ForEach(review.favoriteDishes, id: \.self) { dish in
                        Button(action: {
                            // Action for the dish (e.g., show details)
                        }) {
                            Text(dish)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(10)
                        }
                    }
                }
            }
            .padding(.horizontal)
            
            // Review Text
            Text(review.reviewText)
                .font(.body)
                .padding(.horizontal)
                .multilineTextAlignment(.center)
            
            // Images (Using URLs from the images array)
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
                                Image(systemName: "photo") // Fallback for failed image load
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
    
    // Formatter for timestamp
    private var timestampFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
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
                .font(.subheadline)
            Text(String(format: "%.1f", score))
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(color)
                .clipShape(Circle())
        }
    }
}

