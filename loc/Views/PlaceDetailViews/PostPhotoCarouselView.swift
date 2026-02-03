//
//  PostPhotoCarouselView.swift
//  loc
//
//  Displays photos in a full-width carousel with page indicator dots
//

import SwiftUI
import UIKit

struct PostPhotoCarouselView: View {
    let photos: [UIImage]
    let onPhotoTapped: (Int) -> Void

    @State private var currentIndex: Int = 0

    private let aspectRatio: CGFloat = 4.0 / 5.0
    private let maxHeight: CGFloat = 400

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = min(width / aspectRatio, maxHeight)

            ZStack(alignment: .bottom) {
                TabView(selection: $currentIndex) {
                    ForEach(photos.indices, id: \.self) { index in
                        photoView(photo: photos[index], index: index)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: height)

                if photos.count > 1 {
                    pageIndicator
                        .padding(.bottom, 12)
                }
            }
            .frame(height: height)
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .frame(maxHeight: maxHeight)
    }

    private func photoView(photo: UIImage, index: Int) -> some View {
        Image(uiImage: photo)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture {
                onPhotoTapped(index)
            }
    }

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(photos.indices, id: \.self) { index in
                Circle()
                    .fill(index == currentIndex ? Color.white : Color.white.opacity(0.5))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
    }
}
