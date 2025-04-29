import SwiftUI

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