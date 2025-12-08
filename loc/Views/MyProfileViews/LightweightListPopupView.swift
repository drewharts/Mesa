//
//  LightweightListPopupView.swift
//  loc
//
//  Created by Claude on 1/20/25.
//

import SwiftUI

struct LightweightListPopupView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var dataManager: DataManager
    
    let lists: [LightweightPlaceList]
    let initialListIndex: Int
    @Binding var placeColors: [UUID: Color]
    
    @State private var currentListIndex: Int
    @State private var showOnlyUnvisited: Bool = false
    @State private var isLoadingMore: Bool = false
    @State private var hasMorePlaces: Bool = true
    @State private var currentPage: Int = 1
    
    // Convenience initializer for single list (backward compatibility)
    init(list: LightweightPlaceList, places: [LightweightPlace], placeColors: Binding<[UUID: Color]>) {
        self.lists = [list]
        self.initialListIndex = 0
        self._placeColors = placeColors
        self._currentListIndex = State(initialValue: 0)
    }
    
    // New initializer for multiple lists with swiping
    init(lists: [LightweightPlaceList], initialListIndex: Int, placeColors: Binding<[UUID: Color]>) {
        self.lists = lists
        self.initialListIndex = initialListIndex
        self._placeColors = placeColors
        self._currentListIndex = State(initialValue: initialListIndex)
    }
    
    // Current list being displayed
    private var currentList: LightweightPlaceList {
        profile.lightweightPlaceLists[currentListIndex]
    }
    
    // Same layout as original popup
    private let cardWidth: CGFloat = UIScreen.main.bounds.width / 2 - 35
    private let cardHeight: CGFloat = 180
    
    private let columns = [
        GridItem(.flexible(), spacing: 15),
        GridItem(.flexible(), spacing: 15)
    ]
    
    // Get all places for the current list (from profile state)
    var allPlaces: [LightweightPlace] {
        return profile.lightweightPlaceListPlaces[currentList.list_id] ?? []
    }
    
    // Filtered places based on visited status
    var filteredPlaces: [LightweightPlace] {
        guard showOnlyUnvisited else { return allPlaces }
        
        // Filter out places that the current user has reviewed
        return allPlaces.filter { place in
            !profile.hasReviewedPlace(placeId: place.place_id)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with list name and controls
                VStack(spacing: 12) {
                    // Top bar with close button and share button
                    HStack {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        // Share button
                        if let userId = profile.user?.id {
                            LightweightListShareButton(lightweightList: currentList, userId: userId)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // List name and place count
                    VStack(spacing: 4) {
                        Text(currentList.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                        
                        Text("\(currentList.place_count) place\(currentList.place_count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        // Show list counter if multiple lists and we have total count
                        if profile.lightweightPlaceLists.count > 1 && profile.totalListCount > 0 {
                            Text("\(currentListIndex + 1) of \(profile.totalListCount)")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Filter toggle
                    HStack {
                        Button(action: {
                            showOnlyUnvisited.toggle()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: showOnlyUnvisited ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(showOnlyUnvisited ? .blue : .gray)
                                
                                Text("Show only unvisited")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 10)
                
                // Content with swiping support
                if profile.lightweightPlaceLists.count > 1 {
                    // Multiple lists - use TabView for swiping
                    TabView(selection: $currentListIndex) {
                        ForEach(profile.lightweightPlaceLists.indices, id: \.self) { index in
                            ListContentView(
                                list: profile.lightweightPlaceLists[index],
                                placeColors: $placeColors,
                                showOnlyUnvisited: $showOnlyUnvisited,
                                isLoadingMore: $isLoadingMore,
                                hasMorePlaces: $hasMorePlaces,
                                currentPage: $currentPage,
                                onLoadMore: loadMoreIfNeeded
                            )
                            .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .onChange(of: currentListIndex) { _, newIndex in
                        // Reset pagination state when switching lists
                        isLoadingMore = false
                        hasMorePlaces = true
                        currentPage = 1
                        
                        // Load more lists when approaching the end (3rd-to-last list)
                        if newIndex >= profile.lightweightPlaceLists.count - 3 {
                            loadMoreListsIfNeeded()
                        }
                    }
                } else {
                    // Single list - no swiping needed
                    ListContentView(
                        list: currentList,
                        placeColors: $placeColors,
                        showOnlyUnvisited: $showOnlyUnvisited,
                        isLoadingMore: $isLoadingMore,
                        hasMorePlaces: $hasMorePlaces,
                        currentPage: $currentPage,
                        onLoadMore: loadMoreIfNeeded
                    )
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            // Load places for the current list
            loadPlacesForCurrentList()
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadPlacesForCurrentList() {
        // Load places for the current list if not already loaded
        if profile.lightweightPlaceListPlaces[currentList.list_id] == nil {
            Task {
                await dataManager.loadPlacesForLightweightList(listId: currentList.list_id)
            }
        }
    }
    
    private func loadMoreIfNeeded() {
        guard !isLoadingMore && hasMorePlaces else { return }
        
        isLoadingMore = true
        let nextPage = currentPage + 1
        
        Task {
            do {
                // Use DataManager method that also updates placeSavers
                let morePlaces = try await dataManager.loadMorePlacesForList(
                    listId: currentList.list_id,
                    page: nextPage,
                    pageSize: 6
                )
                
                await MainActor.run {
                    currentPage = nextPage
                    // Keep loading if we got 6 or more places, stop if we got fewer than 6
                    hasMorePlaces = morePlaces.count >= 6
                    isLoadingMore = false
                }
                
                print("✅ [LightweightListPopupView] Loaded \(morePlaces.count) more places for list (page \(nextPage))")
            } catch {
                await MainActor.run {
                    isLoadingMore = false
                }
                print("❌ [LightweightListPopupView] Error loading more places: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadMoreListsIfNeeded() {
        // Check if we have more lists to load and not currently loading
        guard profile.hasMorePlaceLists && !profile.isLoadingMorePlaceLists else { return }
        
        print("📋 [LightweightListPopupView] Loading more lists (current: \(profile.lightweightPlaceLists.count), approaching end)")
        
        Task {
            if let userId = profile.user?.id {
                await dataManager.loadMorePlaceLists(userId: userId)
            }
        }
    }
}

// MARK: - List Content View

struct ListContentView: View {
    let list: LightweightPlaceList
    @Binding var placeColors: [UUID: Color]
    @Binding var showOnlyUnvisited: Bool
    @Binding var isLoadingMore: Bool
    @Binding var hasMorePlaces: Bool
    @Binding var currentPage: Int
    let onLoadMore: () -> Void
    
    @EnvironmentObject var profile: ProfileViewModel
    
    // Same layout as original popup
    private let cardWidth: CGFloat = UIScreen.main.bounds.width / 2 - 35
    private let cardHeight: CGFloat = 180
    
    private let columns = [
        GridItem(.flexible(), spacing: 15),
        GridItem(.flexible(), spacing: 15)
    ]
    
    // Get all places for this list (from profile state)
    var allPlaces: [LightweightPlace] {
        return profile.lightweightPlaceListPlaces[list.list_id] ?? []
    }
    
    // Filtered places based on visited status
    var filteredPlaces: [LightweightPlace] {
        guard showOnlyUnvisited else { return allPlaces }
        
        // Filter out places that the current user has reviewed
        return allPlaces.filter { place in
            !profile.hasReviewedPlace(placeId: place.place_id)
        }
    }
    
    var body: some View {
        if !filteredPlaces.isEmpty {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 15) {
                    ForEach(Array(filteredPlaces.enumerated()), id: \.element.id) { index, place in
                        LightweightPlaceGridCell(
                            place: place,
                            cardWidth: cardWidth,
                            cardHeight: cardHeight
                        )
                        .onAppear {
                            // Load more when user scrolls to 3rd-to-last item
                            if index == allPlaces.count - 3 {
                                onLoadMore()
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                
                // Loading indicator at bottom
                if isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
                }
            }
        } else {
            VStack(spacing: 8) {
                Spacer()
                if showOnlyUnvisited {
                    Text("No unvisited places in this list")
                        .foregroundColor(.gray)
                    Text("All places have been reviewed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("No places in this list")
                        .foregroundColor(.gray)
                }
                Spacer()
            }
            .padding(.vertical, 30)
        }
    }
}

// Note: LightweightPlaceGridCell is defined in MyPlacesListView.swift and used here

// Preview
struct LightweightListPopupView_Previews: PreviewProvider {
    static var previews: some View {
        LightweightListPopupView(
            list: LightweightPlaceList(
                list_id: "test-id",
                name: "Test List",
                is_public: true,
                image: nil,
                created_at: "2025-01-20",
                updated_at: "2025-01-20",
                distance_meters: 100.0,
                place_count: 5,
                city: "Test City"
            ),
            places: [
                LightweightPlace(
                    place_id: "place-1",
                    name: "Test Place 1",
                    latest_review_photo: nil,
                    external_place_id: nil,
                    tiktok_url: nil
                ),
                LightweightPlace(
                    place_id: "place-2",
                    name: "Test Place 2",
                    latest_review_photo: nil,
                    external_place_id: nil,
                    tiktok_url: nil
                )
            ],
            placeColors: .constant([:])
        )
    }
}
