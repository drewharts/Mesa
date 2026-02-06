//
//  ShimmerView.swift
//  loc
//
//  Reusable shimmer loading animation for placeholder content
//

import SwiftUI

/// Displays an animated shimmer gradient for loading placeholders.
struct ShimmerView: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color.gray.opacity(0.3), location: 0),
                    .init(color: Color.gray.opacity(0.1), location: 0.5),
                    .init(color: Color.gray.opacity(0.3), location: 1)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geometry.size.width * 2)
            .offset(x: -geometry.size.width + (phase * geometry.size.width * 2))
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
        }
        .clipped()
    }
}

#Preview {
    VStack(spacing: 16) {
        ShimmerView()
            .frame(width: 200, height: 150)
            .cornerRadius(12)

        ShimmerView()
            .frame(width: 100, height: 100)
            .cornerRadius(8)
    }
    .padding()
}
