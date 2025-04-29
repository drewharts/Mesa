import SwiftUI
import UIKit

struct RestaurantReviewView: View {
    let review: RestaurantReview
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
        Foundation.NotificationCenter.default.post(name: Foundation.Notification.Name("HideCommentsFor-\(reviewId)"), object: nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Review header with user info and rating
            HStack {
                if let userPhoto = userProfileViewModel.userProfilePhotos[review.userId] {
                    Image(uiImage: userPhoto)
                        .resizable()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 40, height: 40)
                }
                
                VStack(alignment: .leading) {
                    Text(review.userName)
                        .font(.headline)
                    Text(review.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                RatingView(title: "Overall", score: review.overallRating, color: .blue)
            }
            
            // Review content
            Text(review.text)
                .font(.body)
                .lineLimit(isActiveKeyboard ? nil : 3)
            
            // Images if any
            if !review.images.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(review.images, id: \.self) { image in
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .onTapGesture {
                                    selectedImage = image
                                }
                        }
                    }
                }
            }
            
            // Comments section
            if showComments {
                InlineCommentsView(
                    reviewId: review.id,
                    selectedImage: $selectedImage,
                    onKeyboardActive: { isActive in
                        isActiveKeyboard = isActive
                    }
                )
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 2)
    }
} 