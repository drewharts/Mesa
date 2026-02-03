//
//  PopupPlaceCard.swift
//  loc
//
//  Reusable Component: Generic place card for popup grids
//  Used by: TikToksPopupView, ReviewsListPopupView, and future popup views
//  DUMB Component: Pure display with configurable behavior
//
//  Configuration Options:
//  - preferTikTokThumbnail: Whether to prioritize TikTok thumbnail over review photo (default: true)
//  - allowDelete: Whether to show delete option on long press (default: false)
//  - deleteTitle: Title for delete confirmation alert
//  - deleteMessage: Message for delete confirmation alert
//  - onDelete: Callback when delete is confirmed
//  - onNavigate: Custom navigation callback (for external profile views that need to dismiss the profile)

import SwiftUI

struct PopupPlaceCard: View {
    let place: LightweightPlace

    // Configuration
    var preferTikTokThumbnail: Bool = true
    var allowDelete: Bool = false
    var deleteTitle: String = "Delete Place"
    var deleteMessage: String? = nil
    var onDelete: (() -> Void)? = nil
    /// Custom navigation callback - when provided, bypasses default navigation
    /// Use this for external profile views that need to dismiss the profile sheet first
    var onNavigate: ((String) -> Void)? = nil
    /// Show "Added by [name]" indicator for collaborative lists
    var showAddedBy: Bool = false

    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var showDeleteConfirmation = false
    
    // MARK: - Computed Properties
    
    private var placeColor: Color {
        let hash = place.place_id.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.8)
    }
    
    private var computedDeleteMessage: String {
        deleteMessage ?? "Are you sure you want to delete \"\(place.name)\"? This action cannot be undone."
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
                    // Use custom navigation (e.g., for external profile views)
                    customNavigate(place.place_id)
                } else {
                    // Default navigation - just dismiss popup and show place
                    selectedPlaceVM.navigateToPlace(placeId: place.place_id) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .modifier(DeleteGestureModifier(
                allowDelete: allowDelete,
                showDeleteConfirmation: $showDeleteConfirmation
            ))
            .alert(deleteTitle, isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    onDelete?()
                }
            } message: {
                Text(computedDeleteMessage)
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
        if preferTikTokThumbnail {
            // TikTok-style: prioritize TikTok thumbnail
            if let tiktokUrl = place.tiktok_url,
               let thumbnailURL = TikTokMetadataCache.shared.getCachedThumbnailUrl(for: tiktokUrl) {
                tiktokThumbnailView(thumbnailURL: thumbnailURL, tiktokUrl: tiktokUrl, size: size)
            } else if let photoUrl = place.latest_review_photo, let url = URL(string: photoUrl) {
                reviewPhotoView(url: url, size: size)
            } else {
                placeholderView
            }
        } else {
            // Reviews-style: prioritize review photo
            if let photoUrl = place.latest_review_photo, let url = URL(string: photoUrl) {
                reviewPhotoView(url: url, size: size)
            } else if let tiktokUrl = place.tiktok_url,
                      let thumbnailURL = TikTokMetadataCache.shared.getCachedThumbnailUrl(for: tiktokUrl) {
                tiktokThumbnailView(thumbnailURL: thumbnailURL, tiktokUrl: nil, size: size)
            } else {
                placeholderView
            }
        }
    }
    
    @ViewBuilder
    private func tiktokThumbnailView(thumbnailURL: String, tiktokUrl: String?, size: CGSize) -> some View {
        AsyncImage(url: URL(string: thumbnailURL)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipped()
            case .failure:
                Color.clear
            case .empty:
                loadingPlaceholder
                    .frame(width: size.width, height: size.height)
                    .onAppear {
                        // Prefetch metadata if tiktokUrl is provided
                        if let tiktokUrl = tiktokUrl {
                            Task {
                                _ = await TikTokMetadataCache.shared.getMetadata(for: tiktokUrl)
                            }
                        }
                    }
            @unknown default:
                Color.clear
            }
        }
    }
    
    @ViewBuilder
    private func reviewPhotoView(url: URL, size: CGSize) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipped()
            case .failure:
                Color.clear
            case .empty:
                loadingPlaceholder
                    .frame(width: size.width, height: size.height)
            @unknown default:
                Color.clear
            }
        }
    }
    
    private var placeholderView: some View {
        Color.clear
            .onAppear {
                // Prefetch TikTok metadata if URL exists but no cached thumbnail
                if preferTikTokThumbnail, let tiktokUrl = place.tiktok_url {
                    Task {
                        _ = await TikTokMetadataCache.shared.getMetadata(for: tiktokUrl)
                    }
                }
            }
    }
    
    private var loadingPlaceholder: some View {
        Color.gray.opacity(0.3)
            .overlay(
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.8)
            )
    }
}

// MARK: - Delete Gesture Modifier

/// Conditional long press gesture modifier for showing delete confirmation
private struct DeleteGestureModifier: ViewModifier {
    let allowDelete: Bool
    @Binding var showDeleteConfirmation: Bool

    func body(content: Content) -> some View {
        if allowDelete {
            content.onLongPressGesture {
                showDeleteConfirmation = true
            }
        } else {
            content
        }
    }
}

