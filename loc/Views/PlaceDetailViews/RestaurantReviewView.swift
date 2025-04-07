//
//  PlaceReviewView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 3/1/25.
//

import SwiftUI
import UIKit

struct PlaceReviewsView: View {
    @Binding var selectedImage: UIImage?
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    @State private var activeKeyboardReviewId: String? = nil

    var body: some View {
        ScrollViewReader { scrollProxy in
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
                                    RestaurantReviewView(review: review, 
                                                         selectedImage: $selectedImage,
                                                         isActiveKeyboard: Binding(
                                                            get: { activeKeyboardReviewId == review.id },
                                                            set: { isActive in
                                                                if isActive {
                                                                    activeKeyboardReviewId = review.id
                                                                    scrollToReview(review.id, proxy: scrollProxy)
                                                                } else if activeKeyboardReviewId == review.id {
                                                                    activeKeyboardReviewId = nil
                                                                }
                                                            }
                                                         ))
                                        .environmentObject(userProfileViewModel)
                                        .id(review.id) // Give each review a stable ID
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
        .onAppear {
            // Check like statuses when view appears
            selectedPlaceVM.checkLikeStatuses(userId: profile.userId)
        }
    }
    
    private func scrollToReview(_ reviewId: String, proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation {
                proxy.scrollTo(reviewId, anchor: .top)
            }
        }
    }
}

struct RestaruantReviewViewProfileInformation: View {
    let review: Review
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    @State private var showProfileView = false

    var body: some View {
        HStack(alignment: .center, spacing: 16) { // Increased spacing between photo and text
            // Profile Photo from Cache
            if let profilePhoto = profile.profilePhoto(forUserId: review.userId) {
                Image(uiImage: profilePhoto)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    .onTapGesture {
                        // Check if this is the logged-in user's profile
                        if review.userId == profile.userId {
                            // Show the user's own profile page directly
                            showProfileView = true
                        } else {
                            // For other users, fetch and show their profile
                            firestoreService.fetchUserById(userId: review.userId) { profileData in
                                if let profileData = profileData {
                                    userProfileViewModel.selectUser(profileData, currentUserId: profile.userId)
                                }
                            }
                        }
                    }
                    .background(
                        NavigationLink(destination: ProfileView(), isActive: $showProfileView) {
                            EmptyView()
                        }
                    )
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
        let components = calendar.dateComponents([.minute, .hour, .day], from: date, to: now)
        
        if let minutes = components.minute, minutes < 60 && (components.hour ?? 0) == 0 && (components.day ?? 0) == 0 {
            return minutes == 0 ? "Just now" : "\(minutes)m"
        } else if let hours = components.hour, hours < 24 && (components.day ?? 0) == 0 {
            return "\(hours)h"
        } else if let days = components.day {
            return "\(days)d"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .none
            return formatter.string(from: date)
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
    @Binding var isActiveKeyboard: Bool
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    @State private var showComments = false
    
    // Static dictionary to track which review comments should be hidden
    private static var hiddenComments = [String: Bool]()
    
    // Static method to hide comments for a specific review
    static func hideComments(reviewId: String) {
        // This is called from InlineCommentsView to hide its parent review's comments
        NotificationCenter.default.post(name: Notification.Name("HideCommentsFor-\(reviewId)"), object: nil)
    }

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
                ZStack {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.2)
                        
                        Text("Loading photos...")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 8)
                    }
                }
                .frame(height: 150)
                .padding(.horizontal)
                
            case .loaded:
                if !reviewPhotos.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 16) {
                            ForEach(reviewPhotos, id: \.self) { photo in
                                Image(uiImage: photo)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 150, height: 150)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                                    )
                                    .shadow(radius: 2)
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
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        
                        Text("Failed to load photos: \(error.localizedDescription)")
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal)
                    
                    Button(action: {
                        // Trigger reload of photos
                        selectedPlaceVM.reloadReviewPhotos(for: review)
                    }) {
                        Text("Retry")
                            .font(.footnote)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal)
                
            case .idle:
                ProgressView()
                    .padding()
                    .frame(maxWidth: .infinity)
            }
            
            if showComments {
                // Show comments section when expanded
                VStack(alignment: .leading, spacing: 10) {
                    // Embedded comments view
                    InlineCommentsView(reviewId: review.id, selectedImage: $selectedImage, onKeyboardActive: { isActive in
                        isActiveKeyboard = isActive
                    })
                        .padding(.leading, 15) // Indentation for comments
                }
                .padding(8)
                .padding(.horizontal)
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                // Show reply button when comments are hidden
                HStack(spacing: 8) {
                    // Small horizontal line
                    Rectangle()
                        .frame(width: 16, height: 1)
                        .foregroundColor(.gray.opacity(0.5))
                    
                    // Comment button positioned to the left
                    Button(action: {
                        // Load comments if needed before showing
                        if !showComments {
                            // Only fetch comments if we don't already have them
                            if selectedPlaceVM.commentLoadingState(for: review.id) == .idle {
                                selectedPlaceVM.loadCommentsForReview(reviewId: review.id)
                            }
                            withAnimation {
                                showComments.toggle()
                            }
                        }
                    }) {
                        let commentCount = selectedPlaceVM.commentCount(for: review.id)
                        Text(commentCount > 0 ? 
                             "Show \(commentCount) \(commentCount == 1 ? "reply" : "replies")" : 
                             "Reply")
                            .font(.footnote)
                            .foregroundColor(.gray)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                }
                .padding(.leading, 30) // Left padding to align with the indentation
                .padding(.bottom, 10)
            }
        }
        .padding(.vertical)
        .onAppear {
            // Check like statuses using the proper userId from profile
            selectedPlaceVM.checkLikeStatuses(userId: profile.userId)
            
            // Listen for the hide comments notification
            NotificationCenter.default.addObserver(forName: Notification.Name("HideCommentsFor-\(review.id)"), object: nil, queue: .main) { _ in
                withAnimation {
                    showComments = false
                }
            }
        }
        .onDisappear {
            // Remove the observer when view disappears
            NotificationCenter.default.removeObserver(self, name: Notification.Name("HideCommentsFor-\(review.id)"), object: nil)
        }
    }
}

// Create an inline version of the comments view to embed within the review
struct InlineCommentsView: View {
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    @State private var commentText = ""
    @State private var selectedImages: [UIImage] = []
    @State private var isPickerPresented = false
    @State private var showingReplyField = false
    @State private var loadedCommentLimit = 5
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var isTextFieldFocused: Bool
    @Binding var selectedImage: UIImage?
    
    let reviewId: String
    let onKeyboardActive: (Bool) -> Void
    
    init(reviewId: String, selectedImage: Binding<UIImage?>, onKeyboardActive: @escaping (Bool) -> Void) {
        self.reviewId = reviewId
        self._selectedImage = selectedImage
        self.onKeyboardActive = onKeyboardActive
    }
    
    var body: some View {
        ScrollViewReader { scrollProxy in
            VStack(spacing: 12) {
                // Comments list
                let comments = selectedPlaceVM.comments(for: reviewId)
                let totalCommentCount = selectedPlaceVM.commentCount(for: reviewId)
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
                        
                        // If no comments, automatically focus the reply field
                        if showingReplyField {
                            // Comment input field
                            HStack(spacing: 10) {
                                // Comment text field with automatic focus
                                TextField("Add a comment...", text: $commentText)
                                    .font(.footnote)
                                    .padding(8)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(15)
                                    .foregroundColor(.primary)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 15)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                    .focused($isTextFieldFocused)
                                    .onAppear {
                                        // Automatically focus when shown
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                            isTextFieldFocused = true
                                            // Scroll to ensure input field is visible
                                            scrollProxy.scrollTo("commentInputField", anchor: .bottom)
                                        }
                                    }
                                
                                // Submit button
                                Button(action: {
                                    submitComment()
                                    showingReplyField = false
                                    isTextFieldFocused = false
                                }) {
                                    Image(systemName: "paperplane.fill")
                                        .foregroundColor(commentText.isEmpty && selectedImages.isEmpty ? .gray : .blue)
                                        .font(.footnote)
                                }
                                .disabled(commentText.isEmpty && selectedImages.isEmpty)
                                
                                // Photo button with indicator dot when images are selected
                                Button(action: {
                                    isPickerPresented = true
                                }) {
                                    ZStack(alignment: .topTrailing) {
                                        Image(systemName: "photo")
                                            .foregroundColor(!selectedImages.isEmpty ? .blue : .gray)
                                            .font(.footnote)
                                        
                                        // Show count indicator if images are selected
                                        if !selectedImages.isEmpty {
                                            Text("\(selectedImages.count)")
                                                .font(.system(size: 10))
                                                .foregroundColor(.white)
                                                .frame(width: 14, height: 14)
                                                .background(Circle().fill(Color.red))
                                                .offset(x: 8, y: -8)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .id("commentInputField")
                            
                            // Display selected images preview if any
                            if !selectedImages.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(0..<selectedImages.count, id: \.self) { index in
                                            ZStack(alignment: .topTrailing) {
                                                Image(uiImage: selectedImages[index])
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 60, height: 60)
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                                                    )
                                                
                                                // Remove button
                                                Button(action: {
                                                    selectedImages.remove(at: index)
                                                }) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .foregroundColor(.white)
                                                        .background(Circle().fill(Color.black.opacity(0.6)))
                                                        .font(.system(size: 16))
                                                }
                                                .padding(4)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                }
                                .frame(height: 70)
                                .padding(.bottom, 5)
                            }
                        } else {
                            // Only show reply button when not yet replying
                            HStack(spacing: 8) {
                                // Small horizontal line
                                Rectangle()
                                    .frame(width: 16, height: 1)
                                    .foregroundColor(.gray.opacity(0.5))
                                
                                Button(action: {
                                    showingReplyField = true
                                    // Add a small delay to ensure view updates first
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        isTextFieldFocused = true
                                    }
                                }) {
                                    Text("Reply")
                                        .font(.footnote)
                                        .foregroundColor(.gray)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 15) // Indent to align
                            .padding(.vertical, 5)
                        }
                    } else {
                        // Show existing comments with spacing
                        VStack(spacing: 16) {
                            ForEach(comments) { comment in
                                HStack(alignment: .top, spacing: 5) {
                                    // Actual comment
                                    InlineCommentView(comment: comment, selectedImage: $selectedImage)
                                }
                            }
                            
                            // Load more comments button if there are more to load
                            if comments.count < totalCommentCount {
                                Button(action: {
                                    loadMoreComments()
                                }) {
                                    HStack {
                                        Text("Load more comments")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                        
                                        Image(systemName: "arrow.down.circle")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                    .padding(.vertical, 8)
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                        .padding(.leading, 8)
                        
                        // Add reply button or comment input field below comments
                        if showingReplyField {
                            // Comment input when reply is clicked
                            HStack(spacing: 10) {
                                // Comment text field
                                TextField("Add a comment...", text: $commentText)
                                    .font(.footnote)
                                    .padding(8)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(15)
                                    .foregroundColor(.primary)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 15)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                    .focused($isTextFieldFocused)
                                    .onChange(of: isTextFieldFocused) { focused in
                                        if focused {
                                            // Small delay to ensure UI is updated
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                withAnimation {
                                                    // This will trigger our keyboard height adjustment
                                                    showingReplyField = true
                                                    // Scroll to ensure input field is visible
                                                    scrollProxy.scrollTo("commentInputField", anchor: .bottom)
                                                }
                                            }
                                        }
                                    }
                                
                                // Submit button
                                Button(action: {
                                    submitComment()
                                    showingReplyField = false
                                    isTextFieldFocused = false
                                }) {
                                    Image(systemName: "paperplane.fill")
                                        .foregroundColor(commentText.isEmpty && selectedImages.isEmpty ? .gray : .blue)
                                        .font(.footnote)
                                }
                                .disabled(commentText.isEmpty && selectedImages.isEmpty)
                                
                                // Photo button with indicator dot when images are selected
                                Button(action: {
                                    isPickerPresented = true
                                }) {
                                    ZStack(alignment: .topTrailing) {
                                        Image(systemName: "photo")
                                            .foregroundColor(!selectedImages.isEmpty ? .blue : .gray)
                                            .font(.footnote)
                                        
                                        // Show count indicator if images are selected
                                        if !selectedImages.isEmpty {
                                            Text("\(selectedImages.count)")
                                                .font(.system(size: 10))
                                                .foregroundColor(.white)
                                                .frame(width: 14, height: 14)
                                                .background(Circle().fill(Color.red))
                                                .offset(x: 8, y: -8)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .id("commentInputField") // Give it a stable ID for scrolling
                            
                            // Display selected images preview if any
                            if !selectedImages.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(0..<selectedImages.count, id: \.self) { index in
                                            ZStack(alignment: .topTrailing) {
                                                Image(uiImage: selectedImages[index])
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 60, height: 60)
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                                                    )
                                                
                                                // Remove button
                                                Button(action: {
                                                    selectedImages.remove(at: index)
                                                }) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .foregroundColor(.white)
                                                        .background(Circle().fill(Color.black.opacity(0.6)))
                                                        .font(.system(size: 16))
                                                }
                                                .padding(4)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                }
                                .frame(height: 70)
                                .padding(.bottom, 5)
                            }
                        } else {
                            // Only show reply button when not yet replying
                            HStack(spacing: 8) {
                                // Small horizontal line
                                Rectangle()
                                    .frame(width: 16, height: 1)
                                    .foregroundColor(.gray.opacity(0.5))
                                
                                Button(action: {
                                    showingReplyField = true
                                    // Add a small delay to ensure view updates first
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        isTextFieldFocused = true
                                    }
                                }) {
                                    Text("Reply")
                                        .font(.footnote)
                                        .foregroundColor(.gray)
                                }
                                
                                // Add vertical separator and hide button
                                Rectangle()
                                    .fill(Color.gray.opacity(0.5))
                                    .frame(width: 1, height: 14)
                                    .padding(.horizontal, 8)
                                
                                Button(action: {
                                    // Hide comments when clicked
                                    withAnimation {
                                        onKeyboardActive(false)
                                        isTextFieldFocused = false
                                        RestaurantReviewView.hideComments(reviewId: reviewId)
                                    }
                                }) {
                                    Text("Hide")
                                        .font(.footnote)
                                        .foregroundColor(.gray)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 15) // Indent to align
                            .padding(.vertical, 5)
                        }
                    }
                    
                case .error(let error):
                    Text("Failed to load comments: \(error.localizedDescription)")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.vertical, 5)
                    
                case .idle:
                    ProgressView()
                        .padding()
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, showingReplyField ? keyboardHeight : 0)
            .animation(.easeOut(duration: 0.25), value: keyboardHeight)
            .onChange(of: showingReplyField) { show in
                if show {
                    // When reply field is shown, scroll to it
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation {
                            scrollProxy.scrollTo("commentInputField", anchor: .bottom)
                        }
                    }
                }
            }
            .onChange(of: isTextFieldFocused) { focused in
                // Report keyboard state to parent
                onKeyboardActive(focused)
            }
        }
        .sheet(isPresented: $isPickerPresented) {
            MultiImagePicker(images: $selectedImages, selectionLimit: 5)
        }
        .onAppear {
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
                let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
                keyboardHeight = keyboardFrame.height - 10 // Provide much more space to clear keyboard suggestions
                onKeyboardActive(true)
            }
            
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                keyboardHeight = 0
                onKeyboardActive(false)
            }
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
            NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
            onKeyboardActive(false)
        }
    }
     
    private func loadMoreComments() {
        // Increase the limit and reload comments
        loadedCommentLimit += 5
        
        guard let placeId = selectedPlaceVM.selectedPlace?.id.uuidString else { return }
        selectedPlaceVM.loadMoreComments(placeId: placeId, reviewId: reviewId, limit: loadedCommentLimit)
    }
    
    private func submitComment() {
        // Allow submission if either text or images are present
        guard !commentText.isEmpty || !selectedImages.isEmpty else { return }
        
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
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    @State private var showFullText = false
    @State private var showProfileView = false
    @Binding var selectedImage: UIImage?
    
    private let firestoreService = FirestoreService()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // User info and comment text
            HStack(alignment: .top, spacing: 8) {
                // First try to get the profile photo from cache
                if let cachedPhoto = profile.profilePhoto(forUserId: comment.userId) {
                    Image(uiImage: cachedPhoto)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 34, height: 34)
                        .clipShape(Circle())
                        .onTapGesture {
                            // Check if this is the logged-in user's profile
                            if comment.userId == profile.userId {
                                // Show the user's own profile page directly
                                showProfileView = true
                            } else {
                                // For other users, fetch and show their profile
                                firestoreService.fetchUserById(userId: comment.userId) { profileData in
                                    if let profileData = profileData {
                                        userProfileViewModel.selectUser(profileData, currentUserId: profile.userId)
                                    }
                                }
                            }
                        }
                        .background(
                            NavigationLink(destination: ProfileView(), isActive: $showProfileView) {
                                EmptyView()
                            }
                        )
                // If not in cache, use AsyncImage as fallback
                } else if let url = URL(string: comment.profilePhotoUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Image(systemName: "person.circle")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 34, height: 34)
                                .foregroundColor(.gray)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 34, height: 34)
                                .clipShape(Circle())
                                .onTapGesture {
                                    // Check if this is the logged-in user's profile
                                    if comment.userId == profile.userId {
                                        // Show the user's own profile page directly
                                        showProfileView = true
                                    } else {
                                        // For other users, fetch and show their profile
                                        firestoreService.fetchUserById(userId: comment.userId) { profileData in
                                            if let profileData = profileData {
                                                userProfileViewModel.selectUser(profileData, currentUserId: profile.userId)
                                            }
                                        }
                                    }
                                }
                                .background(
                                    NavigationLink(destination: ProfileView(), isActive: $showProfileView) {
                                        EmptyView()
                                    }
                                )
                        case .failure:
                            Image(systemName: "person.circle")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 34, height: 34)
                                .foregroundColor(.gray)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Image(systemName: "person.circle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 34, height: 34)
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
                        
                        // Like button removed
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
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                                )
                                .onTapGesture {
                                    selectedImage = photos[index]
                                }
                                .shadow(radius: 1)
                        }
                    }
                }
                .frame(height: 60)
                .padding(.leading, 32) // Aligns with the text
            }
        }
    }
    
    // Helper function to format timestamp
    private func formattedTimestamp(_ date: Date) -> String {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.minute, .hour, .day], from: date, to: now)
        
        if let minutes = components.minute, minutes < 60 && (components.hour ?? 0) == 0 && (components.day ?? 0) == 0 {
            return minutes == 0 ? "Just now" : "\(minutes)m"
        } else if let hours = components.hour, hours < 24 && (components.day ?? 0) == 0 {
            return "\(hours)h"
        } else if let days = components.day {
            return "\(days)d"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
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

// Add the FirestoreService as a property
private let firestoreService = FirestoreService()

