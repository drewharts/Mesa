//
//  SelectedPlaceViewModel.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/22/25.
//

import Foundation
import MapboxSearch
import CoreLocation
import UIKit

class SelectedPlaceViewModel: ObservableObject {
    private let firestoreService: FirestoreService
    private let locationManager: LocationManager
    
    @Published var selectedPlace: DetailPlace? {
        didSet {
            if let place = selectedPlace,
               let currentLocation = locationManager.currentLocation {
                loadData(for: place, currentLocation: currentLocation.coordinate)
                loadReviews(for: place)
//                getPlacePhotos(for: place)
                
                // Clear previous likes when loading a new place
                likedReviews.removeAll()
            }
        }
    }
    @Published var isDetailSheetPresented: Bool = false
    @Published var isRestaurantOpen: Bool = false // New property to track open status
    @Published private var placePhotos: [String: [UIImage]] = [:] // Cache for place-level photos by placeId
    @Published private var placeReviews: [String: [Review]] = [:] // Cache for reviews by placeId
    @Published private var reviewPhotos: [String: [UIImage]] = [:] // Cache for review photos by reviewId
    @Published private var userProfilePhotos: [String: UIImage] = [:] // Cache for profile photos by userId
    
    @Published var placeRating: Double = 0
    
    @Published private var photoLoadingStates: [String: LoadingState] = [:] // Loading states for place photos
    @Published private var reviewPhotoLoadingStates: [String: LoadingState] = [:] // Loading states for review photos
    @Published private var profilePhotoLoadingStates: [String: LoadingState] = [:] // Loading states for profile photos
    @Published private var reviewLoadingStates: [String: LoadingState] = [:] // Loading states for reviews

    // Add new property to track liked reviews
    @Published private var likedReviews: Set<String> = []

    // MARK: - Comment Management Properties
    private var placeReviewComments: [String: [Comment]] = [:] // reviewId -> comments
    private var likedComments: Set<String> = [] // commentIds that are liked by the current user
    private var commentLoadingStates: [String: LoadingState] = [:] // reviewId -> loading state
    private var commentPhotos: [String: [UIImage]] = [:] // commentId -> photos
    private var reviewCommentCounts: [String: Int] = [:] // reviewId -> comment count

    // MARK: - Loading State Enum
    enum LoadingState: Equatable {
        case idle
        case loading
        case loaded
        case error(Error)

        static func == (lhs: LoadingState, rhs: LoadingState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.loading, .loading), (.loaded, .loaded):
                return true
            case (.error, .error):
                return true // All errors considered equal for simplicity
            default:
                return false
            }
        }
    }
    
    // MARK: - Initialization
    init(locationManager: LocationManager, firestoreService: FirestoreService) {
        self.locationManager = locationManager
        self.firestoreService = firestoreService
    }
    
    // MARK: - Private Methods
    private func loadData(for place: DetailPlace, currentLocation: CLLocationCoordinate2D) {
        print("Loading data for \(place.name) at location \(currentLocation)")
        
        // Compute whether the restaurant is open now
        let openNow = isRestaurantOpenNow(place)
        
        DispatchQueue.main.async {
            self.isRestaurantOpen = openNow
            self.isDetailSheetPresented = true
        }
    }
    
    func isRestaurantOpenNow(_ place: DetailPlace) -> Bool {
        guard let openHours = place.OpenHours, !openHours.isEmpty else { return false }
        
        let now = Date()
        let calendar = Calendar.current
        let currentWeekday = calendar.component(.weekday, from: now) // Sunday=1, ..., Saturday=7
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentMinutesSinceWeekStart = ((currentWeekday - 1) * 24 * 60) + (currentHour * 60) + currentMinute

        switch openHours[0] {
        case "always_opened":
            return true
        case "temporarily_closed", "permanently_closed":
            return false
        default:
            for periodString in openHours {
                if !periodString.contains("-") || periodString.hasPrefix("note:") { continue }
                
                let components = periodString.split(separator: "-")
                guard components.count == 2 else { continue }
                
                let openParts = components[0].split(separator: ":")
                let closeParts = components[1].split(separator: ":")
                guard openParts.count == 3, closeParts.count == 3,
                      let openDay = Int(openParts[0]), let openHour = Int(openParts[1]), let openMinute = Int(openParts[2]),
                      let closeDay = Int(closeParts[0]), let closeHour = Int(closeParts[1]), let closeMinute = Int(closeParts[2]) else {
                    continue
                }
                
                // No adjustment needed since OpenPeriod already uses Sunday=1, ..., Saturday=7
                let openMinutes = ((openDay - 1) * 24 * 60) + (openHour * 60) + openMinute
                var closeMinutes = ((closeDay - 1) * 24 * 60) + (closeHour * 60) + closeMinute
                
                if closeMinutes <= openMinutes { closeMinutes += 7 * 24 * 60 } // Handle overnight periods
                if currentMinutesSinceWeekStart >= openMinutes && currentMinutesSinceWeekStart <= closeMinutes {
                    return true
                }
            }
            return false
        }
    }
    
    private func loadReviews(for place: DetailPlace) {
        let placeId = place.id.uuidString
        DispatchQueue.main.async {
            self.reviewLoadingStates[placeId] = .loading
        }
        
        firestoreService.fetchReviews(placeId: placeId) { [weak self] reviews, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    print("Error fetching reviews for place \(place.name): \(error.localizedDescription)")
                    self.reviewLoadingStates[placeId] = .error(error)
                    self.placeReviews[placeId] = []
                } else {
                    let fetchedReviews = reviews ?? []
                    self.placeReviews[placeId] = fetchedReviews
                    if self.selectedPlace?.id.uuidString == placeId {
                        self.placeRating = self.calculateAvgRating(for: placeId)
                    }
                    
                    fetchedReviews.forEach { review in
                        self.loadReviewPhotos(for: review)
                        self.loadProfilePhoto(for: review)
                        self.loadCommentCountForReview(placeId: placeId, reviewId: review.id)
                    }
                    self.reviewLoadingStates[placeId] = .loaded
                }
            }
        }
    }
    
    private func calculateAvgRating(for placeId: String) -> Double {
        guard let reviews = placeReviews[placeId], !reviews.isEmpty else { return 0 }
        let total = reviews.reduce(0.0) { $0 + $1.foodRating }
        return total / Double(reviews.count)
    }
    
    private func getPlacePhotos(for place: DetailPlace) {
        let placeId = place.id.uuidString
        DispatchQueue.main.async {
            self.photoLoadingStates[placeId] = .loading
        }
        
        firestoreService.fetchPhotosFromStorage(placeId: placeId) { [weak self] images, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    print("Error fetching photos for place \(placeId): \(error.localizedDescription)")
                    self.photoLoadingStates[placeId] = .error(error)
                    self.placePhotos[placeId] = []
                } else {
                    self.placePhotos[placeId] = images ?? []
                    self.photoLoadingStates[placeId] = .loaded
                }
            }
        }
    }
    
    private func loadReviewPhotos(for review: Review) {
        let reviewId = review.id
        guard !review.images.isEmpty else {
            DispatchQueue.main.async {
                self.reviewPhotos[reviewId] = []
                self.reviewPhotoLoadingStates[reviewId] = .loaded
            }
            return
        }
        
        DispatchQueue.main.async {
            self.reviewPhotoLoadingStates[reviewId] = .loading
        }
        
        firestoreService.fetchPhotosFromStorage(urls: review.images) { [weak self] images, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    print("Error fetching photos for review \(reviewId): \(error.localizedDescription)")
                    self.reviewPhotoLoadingStates[reviewId] = .error(error)
                    self.reviewPhotos[reviewId] = []
                } else {
                    self.reviewPhotos[reviewId] = images ?? []
                    self.reviewPhotoLoadingStates[reviewId] = .loaded
                }
            }
        }
    }
    
    // Public method to reload review photos
    func reloadReviewPhotos(for review: Review) {
        self.loadReviewPhotos(for: review)
    }
    
    private func loadProfilePhoto(for review: Review) {
        let userId = review.userId
        let photoUrlString = review.profilePhotoUrl
        
        guard !photoUrlString.isEmpty else {
            DispatchQueue.main.async {
                self.profilePhotoLoadingStates[userId] = .loaded
                self.userProfilePhotos[userId] = nil
            }
            return
        }
        
        if userProfilePhotos[userId] != nil {
            return
        }
        
        DispatchQueue.main.async {
            self.profilePhotoLoadingStates[userId] = .loading
        }
        
        guard let url = URL(string: photoUrlString) else {
            DispatchQueue.main.async {
                self.profilePhotoLoadingStates[userId] = .error(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid profile photo URL"]))
                self.userProfilePhotos[userId] = nil
            }
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    print("Error fetching profile photo for user \(userId): \(error.localizedDescription)")
                    self.profilePhotoLoadingStates[userId] = .error(error)
                    self.userProfilePhotos[userId] = nil
                } else if let data = data, let image = UIImage(data: data) {
                    self.userProfilePhotos[userId] = image
                    self.profilePhotoLoadingStates[userId] = .loaded
                } else {
                    self.profilePhotoLoadingStates[userId] = .error(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode profile photo"]))
                    self.userProfilePhotos[userId] = nil
                }
            }
        }.resume()
    }
    
    // Update the method to take userId as parameter
    func checkLikeStatuses(userId: String) {
        guard let placeId = selectedPlace?.id.uuidString,
              let reviews = placeReviews[placeId] else { return }
        
        // Clear previous likes before checking
        likedReviews.removeAll()
        
        reviews.forEach { review in
            firestoreService.hasUserLikedReview(userId: userId, reviewId: review.id) { [weak self] isLiked in
                DispatchQueue.main.async {
                    if isLiked {
                        self?.likedReviews.insert(review.id)
                    }
                }
            }
        }
    }
    
    // MARK: - Comment Methods
    
    func loadCommentsForReview(reviewId: String) {
        guard let placeId = selectedPlace?.id.uuidString else { return }
        
        DispatchQueue.main.async {
            self.commentLoadingStates[reviewId] = .loading
        }
        
        firestoreService.fetchComments(placeId: placeId, reviewId: reviewId) { [weak self] comments, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    print("Error loading comments: \(error.localizedDescription)")
                    self.commentLoadingStates[reviewId] = .error(error)
                } else {
                    let fetchedComments = comments ?? []
                    self.placeReviewComments[reviewId] = fetchedComments
                    
                    // Update our count
                    self.reviewCommentCounts[reviewId] = fetchedComments.count
                    
                    self.commentLoadingStates[reviewId] = .loaded
                    
                    for comment in fetchedComments {
                        if !comment.images.isEmpty {
                            self.loadCommentPhotos(for: comment)
                        }
                    }
                }
            }
        }
    }
    
    func addComment(reviewId: String, text: String, images: [UIImage], userId: String, userFirstName: String, userLastName: String, profilePhotoUrl: String) {
        guard let placeId = selectedPlace?.id.uuidString else { return }
        
        let commentId = UUID().uuidString
        
        let comment = Comment(
            id: commentId,
            reviewId: reviewId,
            userId: userId,
            profilePhotoUrl: profilePhotoUrl,
            userFirstName: userFirstName,
            userLastName: userLastName,
            commentText: text,
            timestamp: Date(),
            images: [],
            likes: 0
        )
        
        firestoreService.addComment(placeId: placeId, reviewId: reviewId, comment: comment, images: images) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch result {
                case .success(let savedComment):
                    // Add the comment to our local collection
                    var currentComments = self.placeReviewComments[reviewId] ?? []
                    currentComments.insert(savedComment, at: 0) // Add at the top
                    self.placeReviewComments[reviewId] = currentComments
                    
                    // Update the comment count
                    let currentCount = self.reviewCommentCounts[reviewId] ?? 0
                    self.reviewCommentCounts[reviewId] = currentCount + 1
                    
                    // Ensure loading state is set to loaded
                    self.commentLoadingStates[reviewId] = .loaded
                    
                    // Load comment photos if any
                    if !savedComment.images.isEmpty {
                        self.loadCommentPhotos(for: savedComment)
                    }
                    
                case .failure(let error):
                    print("Error adding comment: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func loadCommentPhotos(for comment: Comment) {
        // Skip if there are no images or if already loaded
        if comment.images.isEmpty || commentPhotos[comment.id] != nil {
            return
        }
        
        firestoreService.fetchPhotosFromStorage(urls: comment.images) { [weak self] images, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    print("Error loading comment photos: \(error.localizedDescription)")
                } else if let images = images {
                    self.commentPhotos[comment.id] = images
                }
            }
        }
    }
    
    func likeComment(comment: Comment, userId: String) {
        guard let placeId = selectedPlace?.id.uuidString else { return }
        
        // Prevent liking your own comment
        if comment.userId == userId {
            print("Cannot like your own comment")
            return
        }
        
        firestoreService.hasUserLikedComment(userId: userId, commentId: comment.id) { [weak self] isLiked in
            guard let self = self else { return }
            
            if isLiked {
                // Unlike the comment
                self.firestoreService.unlikeComment(userId: userId, placeId: placeId, reviewId: comment.reviewId, commentId: comment.id) { [weak self] result in
                    guard let self = self else { return }
                    
                    switch result {
                    case .success:
                        DispatchQueue.main.async {
                            if var currentComments = self.placeReviewComments[comment.reviewId] {
                                if let index = currentComments.firstIndex(where: { $0.id == comment.id }) {
                                    // Create a new Comment instance with updated likes count
                                    var updatedComment = currentComments[index]
                                    updatedComment.likes = max(0, updatedComment.likes - 1)
                                    currentComments[index] = updatedComment
                                    self.placeReviewComments[comment.reviewId] = currentComments
                                    self.likedComments.remove(comment.id)
                                }
                            }
                        }
                    case .failure(let error):
                        print("Error unliking comment: \(error.localizedDescription)")
                    }
                }
            } else {
                // Like the comment
                self.firestoreService.likeComment(userId: userId, placeId: placeId, reviewId: comment.reviewId, commentId: comment.id) { [weak self] result in
                    guard let self = self else { return }
                    
                    switch result {
                    case .success:
                        DispatchQueue.main.async {
                            if var currentComments = self.placeReviewComments[comment.reviewId] {
                                if let index = currentComments.firstIndex(where: { $0.id == comment.id }) {
                                    // Create a new Comment instance with updated likes count
                                    var updatedComment = currentComments[index]
                                    updatedComment.likes += 1
                                    currentComments[index] = updatedComment
                                    self.placeReviewComments[comment.reviewId] = currentComments
                                    self.likedComments.insert(comment.id)
                                }
                            }
                        }
                    case .failure(let error):
                        print("Error liking comment: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    func checkCommentLikeStatuses(userId: String, reviewId: String) {
        guard let comments = placeReviewComments[reviewId] else { return }
        
        // Clear previous comment likes before checking
        likedComments.removeAll()
        
        comments.forEach { comment in
            firestoreService.hasUserLikedComment(userId: userId, commentId: comment.id) { [weak self] isLiked in
                DispatchQueue.main.async {
                    if isLiked {
                        self?.likedComments.insert(comment.id)
                    }
                }
            }
        }
    }
    
    // MARK: - Comment Public Accessors
    
    func comments(for reviewId: String) -> [Comment] {
        return placeReviewComments[reviewId] ?? []
    }
    
    func commentLoadingState(for reviewId: String) -> LoadingState {
        return commentLoadingStates[reviewId] ?? .idle
    }
    
    func commentPhotos(for comment: Comment) -> [UIImage] {
        return commentPhotos[comment.id] ?? []
    }
    
    func isCommentLiked(_ commentId: String) -> Bool {
        return likedComments.contains(commentId)
    }
    
    // Returns the number of comments for a specific review
    func commentCount(for reviewId: String) -> Int {
        // First check our stored counts
        if let count = reviewCommentCounts[reviewId] {
            return count
        }
        // Fall back to the comment array count if needed
        return placeReviewComments[reviewId]?.count ?? 0
    }

    // MARK: - Public Methods
    func addReview(_ review: Review) {
        guard let placeId = selectedPlace?.id.uuidString else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            var currentReviews = self.placeReviews[placeId] ?? []
            currentReviews.append(review)
            self.placeReviews[placeId] = currentReviews
            self.placeRating = self.calculateAvgRating(for: placeId)
            self.loadReviewPhotos(for: review)
            self.loadProfilePhoto(for: review)
        }
    }
    
    func formattedTimestamp(for review: Review) -> String {
        let now = Date()
        let calendar = Calendar.current
        let daysSince = calendar.dateComponents([.day], from: review.timestamp, to: now).day ?? 0
        
        if daysSince < 30 {
            return daysSince == 0 ? "Today" : "\(daysSince) day\(daysSince == 1 ? "" : "s") ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: review.timestamp)
        }
    }
    
    // MARK: - Public Accessors
    var reviews: [Review] {
        guard let placeId = selectedPlace?.id.uuidString else { return [] }
        return placeReviews[placeId] ?? []
    }
    
    var photoLoadingState: LoadingState {
        guard let placeId = selectedPlace?.id.uuidString else { return .idle }
        return photoLoadingStates[placeId] ?? .idle
    }
    
    var photos: [UIImage] {
        guard let placeId = selectedPlace?.id.uuidString else { return [] }
        return placePhotos[placeId] ?? []
    }
    
    func photos(for review: Review) -> [UIImage] {
        return reviewPhotos[review.id] ?? []
    }
    
    func photoLoadingState(for review: Review) -> LoadingState {
        return reviewPhotoLoadingStates[review.id] ?? .idle
    }
    
    func profilePhoto(forUserId userId: String) -> UIImage? {
        return userProfilePhotos[userId]
    }
    
    func profilePhotoLoadingState(forUserId userId: String) -> LoadingState {
        return profilePhotoLoadingStates[userId] ?? .idle
    }
    
    func reviewLoadingState(forPlaceId placeId: String) -> LoadingState {
        return reviewLoadingStates[placeId] ?? .idle
    }
    
    func likeReview(_ review: Review, userId: String) {
        guard let placeId = selectedPlace?.id.uuidString else { return }
        
        // Prevent liking your own review
        if review.userId == userId {
            print("Cannot like your own review")
            return
        }
        
        firestoreService.hasUserLikedReview(userId: userId, reviewId: review.id) { [weak self] isLiked in
            guard let self = self else { return }
            
            if isLiked {
                // Unlike the review
                self.firestoreService.unlikeReview(userId: userId, placeId: placeId, reviewId: review.id) { [weak self] result in
                    guard let self = self else { return }
                    
                    switch result {
                    case .success:
                        DispatchQueue.main.async {
                            if var currentReviews = self.placeReviews[placeId] {
                                if let index = currentReviews.firstIndex(where: { $0.id == review.id }) {
                                    // Create a new Review instance with updated likes count
                                    var updatedReview = currentReviews[index]
                                    updatedReview.likes = max(0, updatedReview.likes - 1)
                                    currentReviews[index] = updatedReview
                                    self.placeReviews[placeId] = currentReviews
                                    self.likedReviews.remove(review.id)
                                }
                            }
                        }
                    case .failure(let error):
                        print("Error unliking review: \(error.localizedDescription)")
                    }
                }
            } else {
                // Like the review
                self.firestoreService.likeReview(userId: userId, placeId: placeId, reviewId: review.id) { [weak self] result in
                    guard let self = self else { return }
                    
                    switch result {
                    case .success:
                        DispatchQueue.main.async {
                            if var currentReviews = self.placeReviews[placeId] {
                                if let index = currentReviews.firstIndex(where: { $0.id == review.id }) {
                                    // Create a new Review instance with updated likes count
                                    var updatedReview = currentReviews[index]
                                    updatedReview.likes += 1
                                    currentReviews[index] = updatedReview
                                    self.placeReviews[placeId] = currentReviews
                                    self.likedReviews.insert(review.id)
                                }
                            }
                        }
                    case .failure(let error):
                        print("Error liking review: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    // Add helper method to check if a review is liked
    func isReviewLiked(_ reviewId: String) -> Bool {
        return likedReviews.contains(reviewId)
    }

    // Load comment count for a review (without loading all comments)
    private func loadCommentCountForReview(placeId: String, reviewId: String) {
        firestoreService.fetchCommentCount(placeId: placeId, reviewId: reviewId) { [weak self] count, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    print("Error fetching comment count: \(error.localizedDescription)")
                } else if let count = count {
                    // Store the count in our dictionary
                    self.reviewCommentCounts[reviewId] = count
                    
                    // Create a placeholder array with the right number of empty comments
                    // This ensures commentCount returns the correct count even before comments are loaded
                    if count > 0 {
                        if self.placeReviewComments[reviewId] == nil {
                            // Store empty array with the right capacity
                            self.placeReviewComments[reviewId] = []
                            
                            // Mark as idle so actual comments can be loaded when needed
                            self.commentLoadingStates[reviewId] = .idle
                        }
                    } else {
                        // If no comments, initialize with empty array
                        self.placeReviewComments[reviewId] = []
                        self.commentLoadingStates[reviewId] = .loaded
                    }
                }
            }
        }
    }
}
