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
                                Text("Be the first to write a review!")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .padding(20)
                            } else {
                                PlaceReviewsListView(reviews: reviews, 
                                                   selectedImage: $selectedImage, 
                                                   scrollProxy: scrollProxy)
                            }
                        }
                    }
                }
            }
        }
    }
} 