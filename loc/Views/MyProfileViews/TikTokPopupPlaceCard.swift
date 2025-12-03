//
//  TikTokPopupPlaceCard.swift
//  loc
//

import SwiftUI

struct TikTokPopupPlaceCard: View {
    let place: LightweightPlace
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @Environment(\.presentationMode) var presentationMode
    
    private var placeColor: Color {
        let hash = place.place_id.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.8)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottom) {
                thumbnailImage
                gradientOverlay
                placeInfo
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
        .onTapGesture { navigateToPlace() }
        .onAppear { prefetchThumbnail() }
    }
    
    private var thumbnailImage: some View {
        Group {
            if let thumbnailURL = thumbnailURL {
                AsyncImage(url: thumbnailURL) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: cardWidth, height: cardHeight)
                        .clipped()
                } placeholder: {
                    Rectangle()
                        .foregroundColor(placeColor)
                        .frame(width: cardWidth, height: cardHeight)
                        .overlay(ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.8))
                }
            } else if let photoURL = photoURL {
                AsyncImage(url: photoURL) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: cardWidth, height: cardHeight)
                        .clipped()
                } placeholder: {
                    Rectangle()
                        .foregroundColor(placeColor)
                        .frame(width: cardWidth, height: cardHeight)
                }
            } else {
                Rectangle()
                    .foregroundColor(placeColor)
                    .frame(width: cardWidth, height: cardHeight)
            }
        }
    }
    
    private var gradientOverlay: some View {
        LinearGradient(
            colors: [.clear, .black.opacity(0.7)],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 60)
    }
    
    private var placeInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(place.name)
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Computed URLs
    
    private var thumbnailURL: URL? {
        guard let tiktokUrl = place.tiktok_url,
              let urlString = TikTokMetadataCache.shared.getCachedThumbnailUrl(for: tiktokUrl)
        else { return nil }
        return URL(string: urlString)
    }
    
    private var photoURL: URL? {
        guard let urlString = place.latest_review_photo else { return nil }
        return URL(string: urlString)
    }
    
    // MARK: - Actions
    
    private func navigateToPlace() {
        Task {
            guard let detailPlace = try? await PlaceService.shared.fetchPlace(withId: place.place_id) else { return }
            await MainActor.run {
                selectedPlaceVM.selectPlaceAndFetchDetails(detailPlace, shouldAnimateMap: true)
                selectedPlaceVM.isDetailSheetPresented = true
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    private func prefetchThumbnail() {
        guard let tiktokUrl = place.tiktok_url else { return }
        Task { _ = await TikTokMetadataCache.shared.getMetadata(for: tiktokUrl) }
    }
}

