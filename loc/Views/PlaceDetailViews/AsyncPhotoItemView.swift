//
//  AsyncPhotoItemView.swift
//  loc
//
//  Displays a photo from URL using AsyncImage with shimmer placeholder.
//

import SwiftUI

/// Displays a photo from URL using AsyncImage with shimmer placeholder.
struct AsyncPhotoItemView: View {
    let item: PhotoItem
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        AsyncImage(url: URL(string: item.url)) { phase in
            switch phase {
            case .empty:
                ShimmerView()

            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity.animation(.easeIn(duration: 0.2)))

            case .failure:
                failedView

            @unknown default:
                ShimmerView()
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.gray.opacity(0.1), lineWidth: 0.5)
        )
    }

    private var failedView: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo")
                .font(.title2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.1))
    }
}
