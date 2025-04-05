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
    @EnvironmentObject var profile: ProfileViewModel

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
        .onAppear {
            // Check like statuses when view appears
            selectedPlaceVM.checkLikeStatuses(userId: profile.userId)
        }
    }
}

struct RestaruantReviewViewProfileInformation: View {
    let review: Review
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var profile: ProfileViewModel

    var body: some View {
        HStack(alignment: .center, spacing: 16) { // Increased spacing between photo and text
            // Profile Photo from Cache
            if let profilePhoto = profile.profilePhoto(forUserId: review.userId) {
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

struct RestaruantReviewViewMustOrder: View {
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
    @EnvironmentObject var profile: ProfileViewModel
    @State private var showComments = false

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
            RestaruantReviewViewMustOrder(review: review)
            
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
            
            // Add Comment and Like buttons
            HStack(spacing: 20) {
                
                // Comment button
                Button(action: {
                    // Load comments if needed before showing
                    if !showComments {
                        selectedPlaceVM.loadCommentsForReview(reviewId: review.id)
                        selectedPlaceVM.checkCommentLikeStatuses(userId: profile.userId, reviewId: review.id)
                    }
                    withAnimation {
                        showComments.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: showComments ? "bubble.left.fill" : "bubble.left")
                            .foregroundColor(.gray)
                            .opacity(0.7)
                        
                        Text("Comments")
                            .font(.footnote)
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
            
            // Comments section (expandable/collapsible)
            if showComments {
                VStack(alignment: .leading, spacing: 10) {
                    // Comments title
                    HStack {
                        Text("Comments")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 5)
                    
                    // Embedded comments view
                    InlineCommentsView(reviewId: review.id)
                        .padding(.leading, 15) // Indentation for comments
                }
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical)
        .onAppear {
            // Check like statuses using the proper userId from profile
            selectedPlaceVM.checkLikeStatuses(userId: profile.userId)
        }
    }
}

// Create an inline version of the comments view to embed within the review
struct InlineCommentsView: View {
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var profile: ProfileViewModel
    @State private var commentText = ""
    @State private var selectedImages: [UIImage] = []
    @State private var isPickerPresented = false
    
    let reviewId: String
    
    var body: some View {
        VStack(spacing: 12) {
            // Comments list
            let comments = selectedPlaceVM.comments(for: reviewId)
            let loadingState = selectedPlaceVM.commentLoadingState(for: reviewId)
            
            switch loadingState {
            case .loading:
                ProgressView()
                    .padding()
                    .frame(maxWidth: .infinity)
                
            case .loaded:
                if comments.isEmpty {
                    Text("No comments yet. Be the first to comment!")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.vertical, 5)
                } else {
                    // Comments thread with connection line
                    VStack(spacing: 6) {
                        ForEach(comments) { comment in
                            HStack(alignment: .top, spacing: 0) {
                                // Curved connection line
                                ConnectionLine()
                                    .stroke(Color.gray.opacity(0.5), lineWidth: 1.5)
                                    .frame(width: 20, height: 30)
                                    .padding(.top, 12)
                                
                                // Actual comment
                                InlineCommentView(comment: comment)
                            }
                        }
                    }
                    .padding(.leading, 8)
                }
                
            case .error(let error):
                Text("Failed to load comments: \(error.localizedDescription)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.vertical, 5)
                
            case .idle:
                Text("Loading comments...")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.vertical, 5)
            }
            
            // Add comment input
            HStack(spacing: 10) {
                // Comment text field
                TextField("Add a comment...", text: $commentText)
                    .font(.footnote)
                    .padding(8)
                    .background(Color(.systemBackground))
                    .cornerRadius(15)
                    .foregroundColor(.primary) // Use .primary for proper dark/light mode colors
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                
                // Submit button
                Button(action: {
                    submitComment()
                }) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(commentText.isEmpty ? .gray : .blue)
                        .font(.footnote)
                }
                .disabled(commentText.isEmpty)
                
                // Photo button
                Button(action: {
                    isPickerPresented = true
                }) {
                    Image(systemName: "photo")
                        .foregroundColor(.gray)
                        .font(.footnote)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
        }
        .sheet(isPresented: $isPickerPresented) {
            MultiImagePicker(images: $selectedImages, selectionLimit: 5)
        }
    }
    
    private func submitComment() {
        guard !commentText.isEmpty else { return }
        
        selectedPlaceVM.addComment(
            reviewId: reviewId,
            text: commentText,
            images: selectedImages,
            userId: profile.userId,
            userFirstName: profile.currentUser?.firstName ?? "unknown",
            userLastName: profile.currentUser?.lastName ?? "unknown",
            profilePhotoUrl: profile.currentUser?.profilePhotoURL?.absoluteString ?? ""
        )
        
        // Clear form
        commentText = ""
        selectedImages = []
    }
}

// Simplified inline comment view
struct InlineCommentView: View {
    let comment: loc.Comment
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var profile: ProfileViewModel
    @State private var showFullText = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // User info and comment text
            HStack(alignment: .top, spacing: 8) {
                // Profile photo (smaller size)
                if let url = URL(string: comment.profilePhotoUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Image(systemName: "person.circle")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .foregroundColor(.gray)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 24, height: 24)
                                .clipShape(Circle())
                        case .failure:
                            Image(systemName: "person.circle")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .foregroundColor(.gray)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Image(systemName: "person.circle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundColor(.gray)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("\(comment.userFirstName) \(comment.userLastName)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary) // Use .primary for dark mode support
                        
                        Text(formattedTimestamp(comment.timestamp))
                            .font(.caption2)
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        // Like button (smaller)
                        Button(action: {
                            selectedPlaceVM.likeComment(comment: comment, userId: profile.userId)
                        }) {
                            HStack(spacing: 2) {
                                Image(systemName: selectedPlaceVM.isCommentLiked(comment.id) ? "heart.fill" : "heart")
                                    .foregroundColor(selectedPlaceVM.isCommentLiked(comment.id) ? .red : .gray)
                                    .font(.caption2)
                                
                                Text("\(comment.likes)")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                        .disabled(comment.userId == profile.userId)
                        .opacity(comment.userId == profile.userId ? 0.5 : 1)
                    }
                    
                    // Comment text
                    Text(comment.commentText)
                        .font(.caption)
                        .foregroundColor(.primary) // Use .primary for dark mode support
                        .lineLimit(showFullText ? nil : 3)
                        .onTapGesture {
                            withAnimation {
                                showFullText.toggle()
                            }
                        }
                }
            }
            
            // Show photos if any (smaller)
            let photos = selectedPlaceVM.commentPhotos(for: comment)
            if !photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(0..<photos.count, id: \.self) { index in
                            Image(uiImage: photos[index])
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
                .frame(height: 60)
                .padding(.leading, 32) // Aligns with the text
            }
        }
        .padding(8)
        .background(Color(.secondarySystemBackground)) // Better dark/light mode support
        .cornerRadius(8)
    }
    
    // Helper function to format timestamp
    private func formattedTimestamp(_ date: Date) -> String {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.minute, .hour, .day], from: date, to: now)
        
        if let minutes = components.minute, minutes < 60 {
            return minutes == 0 ? "Just now" : "\(minutes)m"
        } else if let hours = components.hour, hours < 24 {
            return "\(hours)h"
        } else if let days = components.day, days < 7 {
            return "\(days)d"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }
}

// Custom shape for the curved connection line
struct ConnectionLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Start at top center
        path.move(to: CGPoint(x: rect.midX, y: 0))
        
        // Draw curved line to right side
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control: CGPoint(x: rect.midX, y: rect.midY - 5)
        )
        
        return path
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

