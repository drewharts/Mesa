//
//  VisiblePlacesPopupView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/29/25.
//

import SwiftUI
import MapKit

struct VisiblePlacesPopupView: View {
    let mapRegion: MKCoordinateRegion?
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @EnvironmentObject var mapViewModel: MapViewModel
    @EnvironmentObject var profile: ProfileViewModel
    
    @State private var loadedImageCount = 0
    @State private var isLoadingImages = false
    
    // Get all places currently visible on the map from viewport annotations
    var visiblePlaces: [PlaceAnnotation] {
        guard let mapRegion = mapRegion else {
            return mapViewModel.viewportAnnotations
        }
        
        // Filter annotations to only include those within the visible map bounds
        return mapViewModel.viewportAnnotations.filter { annotation in
            let placeLat = annotation.coordinate.latitude
            let placeLon = annotation.coordinate.longitude
            
            // Check if place is within the visible map region
            let latMin = mapRegion.center.latitude - mapRegion.span.latitudeDelta / 2
            let latMax = mapRegion.center.latitude + mapRegion.span.latitudeDelta / 2
            let lonMin = mapRegion.center.longitude - mapRegion.span.longitudeDelta / 2
            let lonMax = mapRegion.center.longitude + mapRegion.span.longitudeDelta / 2
            
            return placeLat >= latMin && placeLat <= latMax && 
                   placeLon >= lonMin && placeLon <= lonMax
        }
    }
    
    // Grid layout matching ProfileView lists (consistent spacing)
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Spacer()
                    Text("Places in View")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                // Place count subtitle
                Text("\(visiblePlaces.count) place\(visiblePlaces.count == 1 ? "" : "s") in visible area")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 20)
                
                // Content
                if !visiblePlaces.isEmpty {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(Array(visiblePlaces.enumerated()), id: \.element.id) { index, annotation in
                                VisiblePlaceGridCell(
                                    annotation: annotation,
                                    onDismiss: { dismiss() }
                                )
                                .onAppear {
                                    // Load next batch when user scrolls near the end
                                    loadImagesIfNeeded(for: index)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                } else {
                    VStack(spacing: 8) {
                        Spacer()
                        Image(systemName: "map")
                            .font(.system(size: 32))
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text("No places in view")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        Text("Try zooming out or panning to see more places")
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.7))
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .padding(.vertical, 30)
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            // Load first batch of images
            loadNextBatch()
        }
    }
    
    private func loadImagesIfNeeded(for index: Int) {
        // Load next batch when we're 3 items away from the last loaded item
        if index >= loadedImageCount - 3 && !isLoadingImages {
            loadNextBatch()
        }
    }
    
    private func loadNextBatch() {
        guard !isLoadingImages else { return }
        
        // Get the next 6 place IDs that haven't been loaded yet
        let startIndex = loadedImageCount
        let endIndex = min(startIndex + 6, visiblePlaces.count)
        
        guard startIndex < endIndex else { return }
        
        let placesToLoad = Array(visiblePlaces[startIndex..<endIndex])
        let placeIds = placesToLoad.map { $0.id }
        
        isLoadingImages = true
        
        Task {
            do {
                let imageMap = try await SupabasePlaceService.shared.fetchPlaceImages(for: placeIds)
                for placeId in placeIds {
                    if let imageUrl = imageMap[placeId] {
                        await loadImage(from: imageUrl, for: placeId)
                    }
                }
                
                let placesNeedingImage = await MainActor.run { () -> [String] in
                    placeIds.filter { detailPlaceViewModel.placeImages[$0] == nil }
                }
                
                if !placesNeedingImage.isEmpty {
                    await profile.fetchFallbackImages(for: placesNeedingImage)
                }
                
                await MainActor.run {
                    loadedImageCount = endIndex
                    isLoadingImages = false
                }
            } catch {
                print("❌ Error batch loading images: \(error)")
                await MainActor.run {
                    loadedImageCount = endIndex
                    isLoadingImages = false
                }
            }
        }
    }
    
    private func loadImage(from urlString: String, for placeId: String) async {
        guard let url = URL(string: urlString) else { return }
        
        // Check if already loaded
        guard detailPlaceViewModel.placeImages[placeId] == nil else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                await MainActor.run {
                    detailPlaceViewModel.placeImages[placeId] = image
                }
            }
        } catch {
            print("❌ Error loading image for place \(placeId): \(error)")
        }
    }
}

struct VisiblePlaceGridCell: View {
    let annotation: PlaceAnnotation
    let onDismiss: () -> Void
    
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var profile: ProfileViewModel
    
    // Generate a consistent color for this place based on its ID
    private var placeColor: Color {
        let hash = annotation.id.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.8)
    }
    
    private var firstTikTokThumbnail: String? {
        if let place = detailPlaceViewModel.places[annotation.id],
           let videos = place.tikTokVideos,
           let firstVideo = videos.first {
            return firstVideo.thumbnailURL
        }
        return profile.getFirstTikTokThumbnailURL(for: annotation.id)
    }
    
    var body: some View {
        // Base Rectangle provides consistent size - aspectRatio works on Rectangle's intrinsic size
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
                Task {
                    await loadPlaceAndNavigate()
                }
            }
    }
    
    // MARK: - Place Info Overlay
    
    private var placeInfoOverlay: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(annotation.name)
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(1)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Photo Content
    
    @ViewBuilder
    private func photoContent(size: CGSize) -> some View {
        if let thumbnailURL = firstTikTokThumbnail {
            tiktokThumbnailView(thumbnailURL: thumbnailURL, size: size)
        } else if let image = detailPlaceViewModel.placeImages[annotation.id] {
            cachedImageView(image: image, size: size)
        } else {
            placeholderView
        }
    }
    
    @ViewBuilder
    private func tiktokThumbnailView(thumbnailURL: String, size: CGSize) -> some View {
        AsyncImage(url: URL(string: thumbnailURL)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipped()
            case .failure:
                Color.clear // Falls back to background placeColor
            case .empty:
                loadingPlaceholder
                    .frame(width: size.width, height: size.height)
            @unknown default:
                Color.clear
            }
        }
    }
    
    @ViewBuilder
    private func cachedImageView(image: UIImage, size: CGSize) -> some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size.width, height: size.height)
            .clipped()
    }
    
    private var placeholderView: some View {
        Color.clear
            .onAppear {
                profile.ensureTikTokThumbnailCached(for: annotation.id)
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
    
    private func loadPlaceAndNavigate() async {
        do {
            // Fetch the full place details
            let fullPlace = try await PlaceService.shared.fetchPlace(withId: annotation.id)
            
            // Navigate to the place detail view
            await MainActor.run {
                // Animate map to place location when tapping from popup tile
                selectedPlaceVM.selectPlaceAndFetchDetails(fullPlace, shouldAnimateMap: true)
                selectedPlaceVM.isDetailSheetPresented = true
                onDismiss()
            }
        } catch {
            print("❌ Error loading place details: \(error)")
        }
    }
}
