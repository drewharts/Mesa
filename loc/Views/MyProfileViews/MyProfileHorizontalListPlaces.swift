//
//  MyProfileHorizontalListPlaces.swift
//  loc
//
//  Created by Andrew Hartsfield II on 5/29/25.
//
import SwiftUI
import Combine

struct MyProfileHorizontalListPlaces: View {
    @EnvironmentObject var viewModel: ProfileViewModel
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @Environment(\.presentationMode) var presentationMode

    let listId: UUID
    @Binding var placeColors: [UUID: Color]
    
    // Performance optimization state
    @State private var scrollDebounceTimer: Timer?
    @State private var lastScrollOffset: CGFloat = 0
    @State private var isNearEnd = false
    
    // Lazy image loading state
    @State private var visiblePlaceIds: Set<UUID> = []
    @State private var loadedImagePlaceIds: Set<UUID> = []
    @State private var memoryCleanupTimer: Timer?
    @State private var scrollViewFrame: CGRect = .zero
    @State private var placeFrames: [UUID: CGRect] = [:]
    
    private func getFirstTikTokThumbnail(for place: DetailPlace) -> String? {
        // Check place's own TikTok videos first
        if let placeTikTokVideos = place.tikTokVideos,
           let firstVideo = placeTikTokVideos.first {
            return firstVideo.thumbnailURL
        }
        
        // Check user's TikTok videos for this place
        let userTikTokVideos = viewModel.getTikTokVideos(for: place.id.uuidString)
        return userTikTokVideos.first?.thumbnailURL
    }
    
    // Check if a place should load its image (only if actually visible on screen and not already loaded)
    private func shouldLoadImage(for place: DetailPlace) -> Bool {
        guard !loadedImagePlaceIds.contains(place.id) else { return false }
        
        guard let placeFrame = placeFrames[place.id] else { return false }
        
        // Check if the place frame intersects with the visible scroll view area
        let visibleRect = CGRect(
            x: scrollViewFrame.minX,
            y: scrollViewFrame.minY,
            width: scrollViewFrame.width,
            height: scrollViewFrame.height
        )
        
        return placeFrame.intersects(visibleRect)
    }
    
    // Update visibility tracking based on actual screen position
    private func updateVisiblePlaces() {
        let newVisiblePlaceIds = Set(placeFrames.compactMap { (placeId, frame) in
            let visibleRect = CGRect(
                x: scrollViewFrame.minX,
                y: scrollViewFrame.minY,
                width: scrollViewFrame.width,
                height: scrollViewFrame.height
            )
            return frame.intersects(visibleRect) ? placeId : nil
        })
        
        // Only update if there's a change to avoid unnecessary re-renders
        if newVisiblePlaceIds != visiblePlaceIds {
            visiblePlaceIds = newVisiblePlaceIds
            print("🔍 [MyProfileHorizontalListPlaces] Updated visible places: \(visiblePlaceIds.count) visible out of \(places.count) loaded")
        }
    }
    
    // Mark a place's image as loaded
    private func markImageAsLoaded(for place: DetailPlace) {
        loadedImagePlaceIds.insert(place.id)
    }
    
    // Clear loaded images for places that are no longer visible (memory optimization)
    private func clearInvisibleImages() {
        let currentlyVisiblePlaceIds = Set(placeFrames.compactMap { (placeId, frame) in
            let visibleRect = CGRect(
                x: scrollViewFrame.minX,
                y: scrollViewFrame.minY,
                width: scrollViewFrame.width,
                height: scrollViewFrame.height
            )
            return frame.intersects(visibleRect) ? placeId : nil
        })
        
        let invisiblePlaceIds = loadedImagePlaceIds.subtracting(currentlyVisiblePlaceIds)
        for placeId in invisiblePlaceIds {
            loadedImagePlaceIds.remove(placeId)
            // Note: We don't clear the actual images from detailPlaceViewModel.placeImages
            // as they might be used elsewhere. The AsyncImage will handle caching.
        }
    }
    
    var places: [DetailPlace] {
        // Use paginated place IDs instead of all place IDs
        let placeIds = viewModel.getDisplayedPlaceIds(for: listId)
        let allPlaceIds = viewModel.userListsPlaces[listId.uuidString] ?? []
        print("🔍 [MyProfileHorizontalListPlaces] List \(listId): All place IDs: \(allPlaceIds.count), Displayed: \(placeIds.count)")
        
        // If pagination hasn't loaded yet but we have places, show first 5
        if placeIds.isEmpty && !allPlaceIds.isEmpty {
            let firstFiveIds = Array(allPlaceIds.prefix(5))
            print("🔍 [MyProfileHorizontalListPlaces] Pagination not ready, showing first 5 places: \(firstFiveIds.count)")
            return firstFiveIds.compactMap { detailPlaceViewModel.places[$0] }
        }
        
        return placeIds.compactMap { detailPlaceViewModel.places[$0] }
    }

    // Smart scroll detection with debouncing
    private func handleScrollDetection() {
        scrollDebounceTimer?.invalidate()
        scrollDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in
            if isNearEnd && viewModel.hasMorePlaces(for: listId) && !viewModel.isLoadingMorePlaces(for: listId) {
                print("🔍 [MyProfileHorizontalListPlaces] Smart loading more places for list \(listId)")
                viewModel.loadNextPageForList(listId: listId)
            }
        }
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Show loaded places
                ForEach(places, id: \.id) { place in
                    Button(action: {
                        selectedPlaceVM.selectedPlace = place
                        selectedPlaceVM.isDetailSheetPresented = true
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        VStack(spacing: 4) {
                            // Lazy image loading: only load images for visible places
                            if shouldLoadImage(for: place) {
                                // Load TikTok thumbnail first, then review image, then colored rectangle
                                if let firstTikTokThumbnail = getFirstTikTokThumbnail(for: place) {
                                    AsyncImage(url: URL(string: firstTikTokThumbnail)) { image in
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 120, height: 80)
                                            .cornerRadius(8)
                                            .clipped()
                                            .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                                            .onAppear {
                                                markImageAsLoaded(for: place)
                                            }
                                    } placeholder: {
                                        Rectangle()
                                            .frame(width: 120, height: 80)
                                            .foregroundColor(.gray.opacity(0.3))
                                            .cornerRadius(8)
                                            .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                                    }
                                } else if let image = detailPlaceViewModel.placeImages[place.id.uuidString] {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 120, height: 80)
                                        .cornerRadius(8)
                                        .clipped()
                                        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                                        .onAppear {
                                            markImageAsLoaded(for: place)
                                        }
                                } else {
                                    Rectangle()
                                        .frame(width: 120, height: 80)
                                        .foregroundColor(detailPlaceViewModel.colorForPlace(placeId: place.id.uuidString))
                                        .cornerRadius(8)
                                        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                                        .onAppear {
                                            markImageAsLoaded(for: place)
                                        }
                                }
                            } else if loadedImagePlaceIds.contains(place.id) {
                                // Show already loaded image
                                if let firstTikTokThumbnail = getFirstTikTokThumbnail(for: place) {
                                    AsyncImage(url: URL(string: firstTikTokThumbnail)) { image in
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 120, height: 80)
                                            .cornerRadius(8)
                                            .clipped()
                                            .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                                    } placeholder: {
                                        Rectangle()
                                            .frame(width: 120, height: 80)
                                            .foregroundColor(.gray.opacity(0.3))
                                            .cornerRadius(8)
                                            .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                                    }
                                } else if let image = detailPlaceViewModel.placeImages[place.id.uuidString] {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 120, height: 80)
                                        .cornerRadius(8)
                                        .clipped()
                                        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                                } else {
                                    Rectangle()
                                        .frame(width: 120, height: 80)
                                        .foregroundColor(detailPlaceViewModel.colorForPlace(placeId: place.id.uuidString))
                                        .cornerRadius(8)
                                        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                                }
                            } else {
                                // Show placeholder for not yet loaded images
                                Rectangle()
                                    .frame(width: 120, height: 80)
                                    .foregroundColor(.gray.opacity(0.2))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                                    )
                                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                            }
                            
                            Text(place.name.prefix(20))
                                .foregroundColor(.black)
                                .fontWeight(.semibold)
                                .font(.footnote)
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                                .frame(width: 120)
                            
                            // Display restaurant type instead of city
                            if let type = detailPlaceViewModel.placeTypes[place.id.uuidString] {
                                Text(type.prefix(20))
                                    .foregroundColor(.black)
                                    .font(.caption)
                                    .fontWeight(.light)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(1)
                                    .frame(width: 120)
                            } else if let city = place.city {
                                Text(city.prefix(20))
                                    .foregroundColor(.black)
                                    .font(.caption)
                                    .fontWeight(.light)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(1)
                                    .frame(width: 120)
                            }
                        }
                        .padding(.trailing, 8)
                        .transition(.opacity.combined(with: .scale))
                        .animation(.easeInOut(duration: 0.3), value: places.count)
                        .background(
                            GeometryReader { geometry in
                                Color.clear
                                    .onAppear {
                                        placeFrames[place.id] = geometry.frame(in: .global)
                                        updateVisiblePlaces()
                                    }
                                    .onChange(of: geometry.frame(in: .global)) { newFrame in
                                        placeFrames[place.id] = newFrame
                                        updateVisiblePlaces()
                                    }
                            }
                        )
                    }
                    .contextMenu {
                        Button {
                            ServiceContainer.shared.placeShareService.sharePlace(place)
                        } label: {
                            Label("Share place", systemImage: "square.and.arrow.up")
                        }
                    }
                    .onAppear {
                        // Smart loading: only load when we're near the end and not already loading
                        if place == places.last {
                            isNearEnd = true
                            handleScrollDetection()
                        }
                    }
                    .onDisappear {
                        if place == places.last {
                            isNearEnd = false
                        }
                    }
                }
                
                // Show a smooth "more places" indicator if there are more places to load
                if viewModel.hasMorePlaces(for: listId) {
                    VStack {
                        Image(systemName: "ellipsis")
                            .font(.title2)
                            .foregroundColor(.gray)
                            .scaleEffect(viewModel.isLoadingMorePlaces(for: listId) ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: viewModel.isLoadingMorePlaces(for: listId))
                        Text("More")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(width: 120, height: 80)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .transition(.opacity.combined(with: .scale))
                }
                
                // Show smooth loading indicator if loading more places
                if viewModel.isLoadingMorePlaces(for: listId) {
                    VStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        Text("Loading...")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .frame(width: 120, height: 80)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(.horizontal, 20)
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            scrollViewFrame = geometry.frame(in: .global)
                            updateVisiblePlaces()
                        }
                        .onChange(of: geometry.frame(in: .global)) { newFrame in
                            scrollViewFrame = newFrame
                            updateVisiblePlaces()
                        }
                }
            )
            }
        }
        .onAppear {
            // Smart initialization: only initialize if needed
            let allPlaceIds = viewModel.userListsPlaces[listId.uuidString] ?? []
            print("🔍 [MyProfileHorizontalListPlaces] Smart onAppear for list \(listId): \(allPlaceIds.count) total places")
            
            if !allPlaceIds.isEmpty && viewModel.getDisplayedPlaceIds(for: listId).isEmpty {
                // Only initialize if we have places but haven't loaded any yet
                viewModel.initializeListPaginationIfNeeded(listId: listId)
            }
            
            // Batch color assignment for better performance
            DispatchQueue.main.async {
                for place in places {
                    if placeColors[place.id] == nil {
                        placeColors[place.id] = Color(
                            red: Double.random(in: 0...1),
                            green: Double.random(in: 0...1),
                            blue: Double.random(in: 0...1)
                        )
                    }
                }
            }
            
            // Start memory cleanup timer for lazy image loading
            memoryCleanupTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                clearInvisibleImages()
            }
        }
        .onDisappear {
            // Clean up timers when view disappears
            scrollDebounceTimer?.invalidate()
            scrollDebounceTimer = nil
            memoryCleanupTimer?.invalidate()
            memoryCleanupTimer = nil
            
            // Clear all tracking sets
            visiblePlaceIds.removeAll()
            loadedImagePlaceIds.removeAll()
        }
    }
}
