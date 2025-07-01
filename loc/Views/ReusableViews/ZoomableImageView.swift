import SwiftUI

struct ZoomableImageView: View {
    let image: UIImage
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 4.0
    
    var body: some View {
        GeometryReader { geometry in
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .scaleEffect(scale)
                .offset(offset)
                .simultaneousGesture(
                    MagnifyGesture()
                        .onChanged { value in
                            let newScale = lastScale * value.magnification
                            scale = min(max(newScale, minScale), maxScale)
                            
                            if scale <= minScale {
                                offset = .zero
                            }
                        }
                        .onEnded { value in
                            lastScale = scale
                            
                            if scale < minScale {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    scale = minScale
                                    offset = .zero
                                }
                                lastScale = minScale
                            }
                        }
                )
                .overlay(
                    // Invisible overlay for drag gesture when zoomed
                    Group {
                        if scale > minScale {
                            Color.clear
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            let newOffset = CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            )
                                            
                                            // Calculate bounds
                                            let imageSize = calculateImageSize(in: geometry)
                                            let scaledImageSize = CGSize(
                                                width: imageSize.width * scale,
                                                height: imageSize.height * scale
                                            )
                                            
                                            let maxOffsetX = max(0, (scaledImageSize.width - geometry.size.width) / 2)
                                            let maxOffsetY = max(0, (scaledImageSize.height - geometry.size.height) / 2)
                                            
                                            offset = CGSize(
                                                width: min(max(newOffset.width, -maxOffsetX), maxOffsetX),
                                                height: min(max(newOffset.height, -maxOffsetY), maxOffsetY)
                                            )
                                        }
                                        .onEnded { _ in
                                            lastOffset = offset
                                        }
                                )
                        }
                    }
                )
                .onTapGesture(count: 2) {
                    // Double tap to zoom in/out
                    withAnimation(.easeInOut(duration: 0.3)) {
                        if scale > minScale {
                            // Zoom out to fit
                            scale = minScale
                            offset = .zero
                            lastScale = minScale
                            lastOffset = .zero
                        } else {
                            // Zoom to 2x
                            scale = 2.0
                            lastScale = 2.0
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .clipped()
        .onChange(of: image) {
            // Reset zoom when image changes
            resetZoom()
        }
    }
    
    private var imageAspectRatio: CGFloat {
        CGFloat(image.size.width) / CGFloat(image.size.height)
    }
    
    private func calculateImageSize(in geometry: GeometryProxy) -> CGSize {
        let containerAspectRatio = geometry.size.width / geometry.size.height
        
        if imageAspectRatio > containerAspectRatio {
            // Image is wider than container
            let width = geometry.size.width
            let height = width / imageAspectRatio
            return CGSize(width: width, height: height)
        } else {
            // Image is taller than container
            let height = geometry.size.height
            let width = height * imageAspectRatio
            return CGSize(width: width, height: height)
        }
    }
    
    private func resetZoom() {
        withAnimation(.easeOut(duration: 0.2)) {
            scale = minScale
            offset = .zero
            lastScale = minScale
            lastOffset = .zero
        }
    }
} 