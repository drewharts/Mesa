import SwiftUI

struct RestaruantReviewViewMustOrder: View {
    let review: RestaurantReview
    
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
