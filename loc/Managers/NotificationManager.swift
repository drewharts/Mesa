import Foundation
import SwiftUI
import Combine

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var pendingNavigation: PendingNavigation?
    @Published var highlightedReviewId: String?
    @Published var pendingTripId: String?
    /// A sheet to open once the main screen is visible (push taps that arrive during cold start or login restore).
    @Published var pendingSheet: AppSheetType?
    
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

    /// Handles a group pick push tap: opens the pick (its result screen once decided), or Tonight
    /// if the payload has no pick id. Queued so a cold-start tap still lands after the app is ready.
    func handleGroupPickNotificationTap(pickId: String?) {
        DispatchQueue.main.async {
            if let pickId, !pickId.isEmpty {
                self.pendingSheet = .groupPick(pickId: pickId)
            } else {
                self.pendingSheet = .tonight
            }
        }
    }

    /// Takes the queued sheet, if any.
    func takePendingSheet() -> AppSheetType? {
        let sheet = pendingSheet
        pendingSheet = nil
        return sheet
    }

    /// Handles trip notification tap by storing pending trip and presenting trips sheet.
    func handleTripNotificationTap(tripId: String) {
        DispatchQueue.main.async {
            self.pendingTripId = tripId
            PresentationService.shared.present(.tripsList)
        }
    }
}

struct PendingNavigation {
    let reviewId: String
    let placeId: String
    let userId: String
} 