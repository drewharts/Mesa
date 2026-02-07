//
//  AsyncPhotoItemView.swift
//  loc
//
//  Displays a photo from URL using progressive loading for Google CDN images.
//  Shows a fast low-res version first, then cross-fades to high-res.
//

import SwiftUI

/// Displays a photo from URL with progressive loading for Google CDN images.
struct AsyncPhotoItemView: View {
    let item: PhotoItem
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    var onLoadFailed: ((String) -> Void)? = nil

    private var isGoogleCDN: Bool {
        item.url.contains("lh3.googleusercontent.com")
    }

    var body: some View {
        Group {
            if isGoogleCDN {
                progressiveGoogleImage
            } else {
                standardImage
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

    // MARK: - Progressive Google CDN Image

    /// Loads a low-res version first, then overlays the high-res version with a cross-fade.
    private var progressiveGoogleImage: some View {
        let lowResURL = URL(string: ImageLoadingUtility.getHighResGoogleURL(item.url, maxSize: 400))
        let highResURL = URL(string: ImageLoadingUtility.getHighResGoogleURL(item.url, maxSize: 1600))

        return ZStack {
            AsyncImage(url: lowResURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    failedView
                        .onAppear { onLoadFailed?(item.url) }
                default:
                    ShimmerView()
                }
            }

            AsyncImage(url: highResURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                        .transition(.opacity.animation(.easeIn(duration: 0.3)))
                case .failure:
                    Color.clear
                        .onAppear { onLoadFailed?(item.url) }
                default:
                    Color.clear
                }
            }
        }
    }

    // MARK: - Standard Image

    /// Loads a non-Google image normally with shimmer placeholder.
    private var standardImage: some View {
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
    }

    // MARK: - Failed View

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
