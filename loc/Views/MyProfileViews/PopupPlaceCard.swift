//
//  PopupPlaceCard.swift
//  loc
//
//  Reusable Component: Generic place card for popup grids
//  Used by: ExternalPlacesPopupView, ReviewsListPopupView, ListContentView, and future popup views
//  DUMB Component: Pure display — parents add .contextMenu for actions
//
//  Configuration Options:
//  - preferExternalThumbnail: Whether to prioritize external video thumbnail over review photo (default: true)
//  - onNavigate: Custom navigation callback (for external profile views that need to dismiss the profile)

import SwiftUI

struct PopupPlaceCard: View {
    let place: LightweightPlace

    // Configuration
    var preferExternalThumbnail: Bool = true
    /// Custom navigation callback - when provided, bypasses default navigation
    /// Use this for external profile views that need to dismiss the profile sheet first
    var onNavigate: ((String) -> Void)? = nil
    /// Show "Added by [name]" indicator for collaborative lists
    var showAddedBy: Bool = false

    @ObservedObject private var externalMetadataCache = ExternalMetadataCache.shared
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @Environment(\.presentationMode) var presentationMode

    // MARK: - Computed Properties

    private var placeColor: Color {
        let hash = place.place_id.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.8)
    }

    // MARK: - Body

    var body: some View {
        Rectangle()
            .fill(placeColor)
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                GeometryReader { geometry in
                    ZStack(alignment: .bottom) {
                        // Photo content overlays the background (bottom layer)
                        photoContent(size: geometry.size)

                        // Gradient overlay for text readability (middle layer)
                        LinearGradient(
                            gradient: Gradient(colors: [.clear, .black.opacity(0.7)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 60)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

                        // Place info overlay (top layer)
                        placeInfoOverlay
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
            .onTapGesture {
                if let customNavigate = onNavigate {
                    customNavigate(place.place_id)
                } else {
                    selectedPlaceVM.navigateToPlace(placeId: place.place_id) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
    }
    
    // MARK: - Place Info Overlay
    
    private var placeInfoOverlay: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(place.name)
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(1)
                .multilineTextAlignment(.leading)

            // Show "Added by" indicator for collaborative lists
            if showAddedBy, let addedByName = place.added_by_name {
                AddedByIndicator(
                    name: addedByName,
                    photoUrl: place.added_by_photo_url
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Photo Content
    
    @ViewBuilder
    private func photoContent(size: CGSize) -> some View {
        if preferExternalThumbnail {
            // External video style: prioritize external video thumbnail
            if let contentUrl = place.content_url,
               let thumbnailURL = externalMetadataCache.getCachedThumbnailUrl(for: contentUrl) {
                externalThumbnailView(thumbnailURL: thumbnailURL, contentUrl: contentUrl, size: size)
            } else if let photoUrl = place.latest_review_photo, let url = URL(string: photoUrl) {
                reviewPhotoView(url: url, size: size)
            } else {
                placeholderView
            }
        } else {
            // Reviews-style: prioritize review photo
            if let photoUrl = place.latest_review_photo, let url = URL(string: photoUrl) {
                reviewPhotoView(url: url, size: size)
            } else if let contentUrl = place.content_url,
                      let thumbnailURL = externalMetadataCache.getCachedThumbnailUrl(for: contentUrl) {
                externalThumbnailView(thumbnailURL: thumbnailURL, contentUrl: nil, size: size)
            } else {
                placeholderView
            }
        }
    }
    
    @ViewBuilder
    private func externalThumbnailView(thumbnailURL: String, contentUrl: String?, size: CGSize) -> some View {
        CachedAsyncImage(url: URL(string: thumbnailURL), targetSize: size) {
            ShimmerView()
                .onAppear {
                    if let contentUrl = contentUrl {
                        Task {
                            _ = await ExternalMetadataCache.shared.getMetadata(for: contentUrl)
                        }
                    }
                }
        }
        .aspectRatio(contentMode: .fill)
        .frame(width: size.width, height: size.height)
        .clipped()
    }
    
    @ViewBuilder
    private func reviewPhotoView(url: URL, size: CGSize) -> some View {
        CachedAsyncImage(url: url, targetSize: size) {
            ShimmerView()
        }
        .aspectRatio(contentMode: .fill)
        .frame(width: size.width, height: size.height)
        .clipped()
    }
    
    private var placeholderView: some View {
        Color.clear
            .onAppear {
                // Prefetch external metadata if URL exists but no cached thumbnail
                if let contentUrl = place.content_url {
                    Task {
                        _ = await ExternalMetadataCache.shared.getMetadata(for: contentUrl)
                    }
                }
            }
    }
}
