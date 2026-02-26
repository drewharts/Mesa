import Foundation
import SwiftUI
import Combine

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var pendingNavigation: PendingNavigation?
    @Published var highlightedReviewId: String?
    
    private init() {}
    
    func handleNotificationTap(reviewId: String, placeId: String, userId: String) {
        DispatchQueue.main.async {
            self.pendingNavigation = PendingNavigation(
                reviewId: reviewId,
                placeId: placeId,
                userId: userId
            )
            self.highlightedReviewId = reviewId
        }
    }
    
    func clearPendingNavigation() {
        pendingNavigation = nil
    }
    
    func clearHighlightedReview() {
        highlightedReviewId = nil
    }
    
    func setHighlightedReview(_ reviewId: String) {
        highlightedReviewId = reviewId
    }
    
    /// Handles follow notification tap by posting notification for UserProfileNavigationViewModel to observe
    func handleFollowNotificationTap(userId: String) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("NavigateToUserProfileFromNotification"),
                object: nil,
                userInfo: ["userId": userId]
            )
        }
    }

    /// Handles place-added-to-list notification tap by posting notification for UserProfileNavigationViewModel to observe.
    func handleListNotificationTap(listId: String) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("NavigateToListFromNotification"),
                object: nil,
                userInfo: ["listId": listId]
            )
        }
    }
}

struct PendingNavigation {
    let reviewId: String
    let placeId: String
    let userId: String
} 