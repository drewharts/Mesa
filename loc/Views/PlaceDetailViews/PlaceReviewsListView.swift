import SwiftUI
import UIKit

struct PlaceReviewsListView : View {
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var notificationManager: NotificationManager
    var reviews: [any ReviewProtocol]
    @State private var activeKeyboardReviewId: String? = nil
    let onPhotoTapped: ([UIImage], Int) -> Void
    let scrollProxy: ScrollViewProxy
    @State private var reviewToDelete: (any ReviewProtocol)? = nil
    @State private var showDeleteConfirmation = false

    var body: some View {
        ForEach(reviews, id: \.id) { review in
            Group {
                if let restaurantReview = review as? RestaurantReview {
                    RestaurantReviewView(review: restaurantReview,
                                       onPhotoTapped: onPhotoTapped,
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
                        
                        .id(review.id)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(notificationManager.highlightedReviewId == review.id ? 
                                   Color.blue.opacity(0.1) : Color.white)
                        .cornerRadius(10)
                        .animation(.easeInOut(duration: 0.3), value: notificationManager.highlightedReviewId)
                } else if let genericReview = review as? GenericReview {
                    GenericReviewView(review: genericReview,
                                    onPhotoTapped: onPhotoTapped,
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
                        .id(review.id)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(notificationManager.highlightedReviewId == review.id ? 
                                   Color.blue.opacity(0.1) : Color.white)
                        .cornerRadius(10)
                        .animation(.easeInOut(duration: 0.3), value: notificationManager.highlightedReviewId)
                }
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                // Only allow deletion if this is the user's own review
                if review.userId == userSession.currentUserId {
                    // Haptic feedback
                    let impactMed = UIImpactFeedbackGenerator(style: .medium)
                    impactMed.impactOccurred()
                    
                    reviewToDelete = review
                    showDeleteConfirmation = true
                }
            }
        }
        .alert("Delete Review", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                reviewToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let review = reviewToDelete {
                    deleteReview(review)
                }
            }
        } message: {
            Text("Are you sure you want to delete this review? This action cannot be undone.")
        }
    }
    
    private func deleteReview(_ review: any ReviewProtocol) {
        selectedPlaceVM.deleteReview(reviewId: review.id) { result in
            switch result {
            case .success:
                print("✅ Review deleted successfully")
                // The view model should handle updating the reviews list
            case .failure(let error):
                print("❌ Failed to delete review: \(error.localizedDescription)")
                // You might want to show an error alert here
            }
        }
        reviewToDelete = nil
    }
    
    private func scrollToReview(_ reviewId: String, proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation {
                proxy.scrollTo(reviewId, anchor: .top)
            }
        }
    }
}