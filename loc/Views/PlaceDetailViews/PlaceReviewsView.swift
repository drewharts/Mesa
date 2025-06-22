import SwiftUI

struct PlaceReviewsView: View {
    let onPhotoTapped: ([UIImage], Int) -> Void
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var notificationManager: NotificationManager
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
                                Text("Be the first to write a review!")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .padding(20)
                            } else {
                                PlaceReviewsListView(reviews: reviews, 
                                                   onPhotoTapped: onPhotoTapped, 
                                                   scrollProxy: scrollProxy)
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
            .ignoresSafeArea(.all, edges: .all)
            .onReceive(notificationManager.$highlightedReviewId) { reviewId in
                if let reviewId = reviewId {
                    // Wait for reviews to load, then scroll to the specific review
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation(.easeInOut(duration: 0.8)) {
                            scrollProxy.scrollTo(reviewId, anchor: .center)
                        }
                        
                        // Add haptic feedback when scrolling to the review
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        
                        // Clear the highlighted review after scrolling
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            notificationManager.clearHighlightedReview()
                        }
                    }
                }
            }
        }
        .onAppear {
            // Check like statuses when view appears
            selectedPlaceVM.checkLikeStatuses(userId: userSession.currentUserId! )
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
