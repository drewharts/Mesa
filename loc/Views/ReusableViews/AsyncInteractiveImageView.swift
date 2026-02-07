//
//  AsyncInteractiveImageView.swift
//  loc
//
//  Image view with pinch-to-zoom and double-tap zoom, loading from URL via AsyncImage.
//

import SwiftUI

/// Image view with pinch-to-zoom and double-tap zoom, loading from URL via AsyncImage.
struct AsyncInteractiveImageView: View {
    let imageURL: String

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var imageSize: CGSize = .zero

    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 4.0

    var body: some View {
        GeometryReader { geometry in
            AsyncImage(url: URL(string: imageURL)) { phase in
                switch phase {
                case .empty:
                    loadingView

                case .success(let image):
                    interactiveImage(image, in: geometry)

                case .failure:
                    failedView

                @unknown default:
                    EmptyView()
                }
            }
        }
        .clipped()
        .onAppear {
            resetZoomState()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: .white))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Failed View

    private var failedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.5))
            Text("Failed to load")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Interactive Image

    /// Builds the interactive image with zoom and pan gestures.
    private func interactiveImage(_ image: Image, in geometry: GeometryProxy) -> some View {
        image
            .resizable()
            .scaledToFit()
            .background(imageSizeReader)
            .scaleEffect(scale)
            .offset(offset)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(magnificationGesture)
            .gesture(scale > 1 ? panGesture(in: geometry) : nil)
            .onTapGesture(count: 2) {
                handleDoubleTap()
            }
    }

    /// Reads the image size for pan bounds calculation.
    private var imageSizeReader: some View {
        GeometryReader { imageGeometry in
            Color.clear.onAppear {
                imageSize = imageGeometry.size
            }
        }
    }

    // MARK: - Gestures

    private var magnificationGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let newScale = lastScale * value.magnification
                scale = min(max(newScale, minScale), maxScale)

                if scale <= minScale {
                    offset = .zero
                }
            }
            .onEnded { _ in
                lastScale = scale

                if scale < minScale {
                    withAnimation(.spring(response: 0.3)) {
                        scale = minScale
                        offset = .zero
                    }
                    lastScale = minScale
                }
            }
    }

    /// Creates pan gesture with bounds based on image scale.
    private func panGesture(in geometry: GeometryProxy) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let newOffset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )

                let scaledSize = CGSize(
                    width: imageSize.width * scale,
                    height: imageSize.height * scale
                )

                let maxX = max(0, (scaledSize.width - geometry.size.width) / 2)
                let maxY = max(0, (scaledSize.height - geometry.size.height) / 2)

                offset = CGSize(
                    width: min(max(newOffset.width, -maxX), maxX),
                    height: min(max(newOffset.height, -maxY), maxY)
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    // MARK: - Actions

    /// Handles double-tap to toggle between zoomed and normal scale.
    private func handleDoubleTap() {
        withAnimation(.spring(response: 0.3)) {
            if scale > minScale {
                scale = minScale
                offset = .zero
                lastScale = minScale
                lastOffset = .zero
            } else {
                scale = 2.5
                lastScale = 2.5
            }
        }
    }

    /// Resets zoom and pan state to defaults.
    private func resetZoomState() {
        scale = 1.0
        lastScale = 1.0
        offset = .zero
        lastOffset = .zero
    }
}
