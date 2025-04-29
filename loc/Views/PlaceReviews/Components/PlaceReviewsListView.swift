import SwiftUI
import UIKit

struct PlaceReviewsListView: View {
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    var reviews: [any ReviewProtocol]
    @State private var activeKeyboardReviewId: String? = nil
    @Binding var selectedImage: UIImage?
    let scrollProxy: ScrollViewProxy

    var body: some View {
        ForEach(reviews, id: \.id) { review in
            if let restaurantReview = review as? RestaurantReview {
                RestaurantReviewView(review: restaurantReview,
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
                    .id(review.id)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .cornerRadius(10)
            } else if let genericReview = review as? GenericReview {
                GenericReviewView(review: genericReview,
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
                    .id(review.id)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .cornerRadius(10)
            }
        }
    }
} 