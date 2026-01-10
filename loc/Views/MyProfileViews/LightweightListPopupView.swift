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
    @EnvironmentObject var mapViewModel: MapViewModel // Add MapViewModel for pending navigation
    
    let lists: [LightweightPlaceList]
    let initialListIndex: Int
    
    @State private var currentListIndex: Int
    @State private var showOnlyUnvisited: Bool = false
    @State private var isLoadingMore: Bool = false
    @State private var hasMorePlaces: Bool = true
    @State private var currentPage: Int = 1
    @State private var showCollaboratorsSheet: Bool = false
    @State private var cachedTabViewHeight: CGFloat = 300 // Cached height to prevent layout shift
    @State private var navigationPath = NavigationPath() // Navigation path for place detail navigation
    
    // Convenience initializer for single list (backward compatibility)
    init(list: LightweightPlaceList, places: [LightweightPlace] = []) {
        self.lists = [list]
        self.initialListIndex = 0
        self._currentListIndex = State(initialValue: 0)
    }
    
    // Initializer for multiple lists with swiping
    init(lists: [LightweightPlaceList], initialListIndex: Int) {
        self.lists = lists
        self.initialListIndex = initialListIndex
        self._currentListIndex = State(initialValue: initialListIndex)
    }
    
    // Current list being displayed (uses passed lists, not profile.lightweightPlaceLists for filtered support)
    private var currentList: LightweightPlaceList {
        guard currentListIndex >= 0 && currentListIndex < lists.count else {
            return lists.first ?? LightweightPlaceList(
                list_id: "",
                name: "Unknown",
                is_public: false,
                image: nil,
                created_at: nil,
                updated_at: nil,
                distance_meters: nil,
                place_count: 0,
                city: nil
            )
        }
        return lists[currentListIndex]
    }
    
    // Get all places for the current list (from profile state) - used for filtering logic
    var allPlaces: [LightweightPlace] {
        return profile.lightweightPlaceListPlaces[currentList.list_id] ?? []
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                    contentSection
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: String.self) { placeId in
                // Navigate to place detail when place ID is pushed onto path
                // Environment objects are inherited from parent hierarchy
                PlaceDetailViewInNavigation(placeId: placeId, minSheetHeight: 250)
            }
        }
        .onChange(of: mapViewModel.pendingPlaceNavigation) { oldValue, newValue in
            // When map annotation is tapped while list sheet is open, navigate to that place
            // MVVM: View coordinates navigation based on ViewModel state
            // This makes annotation taps behave the same as clicking a place tile in the list sheet
            if let placeId = newValue {
                navigationPath.append(placeId)
                // Clear the pending navigation after handling it
                mapViewModel.pendingPlaceNavigation = nil
            }
        }
        .onAppear {
            // Clear navigation path when sheet appears (ensures fresh state each time)
            // MVVM: View manages its own navigation state - reset on each presentation
            // Best Practice: Clear in onAppear rather than onDisappear for reliability
            navigationPath = NavigationPath()
            
            // Load places for the current list
            loadPlacesForCurrentList()
            // Load reviewed place IDs from database via ViewModel for accurate filtering
            loadReviewedPlaceIdsViaViewModel()
            // Calculate initial TabView height
            updateTabViewHeight()
        }
        .onChange(of: allPlaces) { oldValue, newValue in
            // Reload reviewed IDs when places change via ViewModel
            loadReviewedPlaceIdsViaViewModel()
            // Recalculate height when places load (prevents layout shift)
            updateTabViewHeight()
        }
        .onChange(of: showOnlyUnvisited) { oldValue, newValue in
            // Recalculate height when filter changes
            updateTabViewHeight()
        }
        .sheet(isPresented: $showCollaboratorsSheet) {
            if let userId = profile.user?.id {
                ManageCollaboratorsSheet(
                    listId: currentList.list_id,
                    currentUserId: userId
                )
            }
        }
    }
    
    // MARK: - View Components
    
    /// Header section with list name, controls, and filter toggle
    /// Single Responsibility: Display list header UI
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Top bar with list title on left, buttons on right
            HStack(alignment: .center) {
                // List name and place count on the left
                VStack(alignment: .leading, spacing: 4) {
                    Text(currentList.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                    
                    Text("\(currentList.place_count) place\(currentList.place_count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Collaborators button with profile avatars + Share button
                if let userId = profile.user?.id {
                    HStack(alignment: .center, spacing: 12) {
                        // Collaborators button
                        Button {
                            showCollaboratorsSheet = true
                        } label: {
                            // Show profile picture avatars for collaborators (like map annotations)
                            if currentList.hasCollaborators || currentList.isSharedWithMe {
                                CollaboratorAvatarsButton(
                                    isSharedWithMe: currentList.isSharedWithMe,
                                    ownerPhotoUrl: currentList.owner_photo_url,
                                    collaboratorPhotos: currentList.collaborator_photos
                                )
                            } else {
                                // Just show person.2 icon when no collaborators (for adding)
                                Image(systemName: "person.2")
                                    .font(.system(size: 20, weight: .regular))
                                    .foregroundColor(.primary)
                            }
                        }
                        .frame(minWidth: 44, minHeight: 44) // Tap target
                        
                        // Share button (Apple style - clean and simple)
                        LightweightListShareButton(lightweightList: currentList, userId: userId, style: .apple)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            
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
        .padding(.bottom, 12)
    }
    
    /// Content section with list places (TabView for multiple lists, single view for one list)
    /// Single Responsibility: Display list content based on number of lists
    private var contentSection: some View {
        Group {
            if lists.count > 1 {
                multipleListsContent
            } else {
                singleListContent
            }
        }
    }
    
    /// Multiple lists content with TabView
    /// Single Responsibility: Display swipable TabView for multiple lists
    private var multipleListsContent: some View {
        TabView(selection: $currentListIndex) {
            ForEach(lists.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: 0) {
                    ListContentView(
                        list: lists[index],
                        showOnlyUnvisited: $showOnlyUnvisited,
                        isLoadingMore: $isLoadingMore,
                        hasMorePlaces: $hasMorePlaces,
                        currentPage: $currentPage,
                        onLoadMore: loadMoreIfNeeded,
                        onNavigateToPlace: { placeId in
                            navigationPath.append(placeId)
                        }
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .tag(index)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .frame(height: cachedTabViewHeight, alignment: .top)
        .clipped()
        .contentShape(Rectangle())
        .onChange(of: currentListIndex) { _, newIndex in
            // Reset pagination state when switching lists
            isLoadingMore = false
            hasMorePlaces = true
            currentPage = 1
            
            // Reload reviewed IDs for new list's places via ViewModel
            loadReviewedPlaceIdsViaViewModel()
            
            // Recalculate height for new list
            updateTabViewHeight()
            
            // Load more lists when approaching the end (only if using full list, not filtered)
            if newIndex >= lists.count - 3 && lists.count == profile.lightweightPlaceLists.count {
                loadMoreListsIfNeeded()
            }
        }
    }
    
    /// Single list content
    /// Single Responsibility: Display single list without TabView
    private var singleListContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            ListContentView(
                list: currentList,
                showOnlyUnvisited: $showOnlyUnvisited,
                isLoadingMore: $isLoadingMore,
                hasMorePlaces: $hasMorePlaces,
                currentPage: $currentPage,
                onLoadMore: loadMoreIfNeeded,
                onNavigateToPlace: { placeId in
                    navigationPath.append(placeId)
                }
            )
        }
        .frame(maxWidth: .infinity, alignment: .top)
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
        
        Task {
            if let userId = profile.user?.id {
                await dataManager.loadMorePlaceLists(userId: userId)
            }
        }
    }
    
    /// Delegate to ViewModel to load reviewed place IDs (no business logic here)
    private func loadReviewedPlaceIdsViaViewModel() {
        let placeIds = allPlaces.map { $0.place_id }
        Task {
            await profile.loadVerifiedReviewedPlaceIds(for: placeIds)
        }
    }
    
    /// Updates the cached TabView height to prevent layout shifts during async data loading
    /// MVVM: Pure function - updates state based on current content
    /// Staff Engineer: Caches height to prevent visual jumps when data loads asynchronously
    private func updateTabViewHeight() {
        cachedTabViewHeight = calculateTabViewHeight()
    }
    
    /// Single Responsibility: Calculate TabView height based on actual content
    /// MVVM: Pure function - calculates based on current list's place count
    /// Staff Engineer: Uses actual filtered places count for accurate height calculation
    private func calculateTabViewHeight() -> CGFloat {
        // Calculate based on filtered places (respects showOnlyUnvisited filter)
        let filteredCount = showOnlyUnvisited ? 
            allPlaces.filter { !profile.hasVerifiedReviewedPlace(placeId: $0.place_id) }.count :
            allPlaces.count
        
        // Each row has 2 places, approximate row height is 200
        let rows = ceil(Double(filteredCount) / 2.0)
        let estimatedHeight = rows * 200 + 100 // Row height + padding
        
        // Ensure minimum height for empty/loading states, cap at reasonable max
        return max(300, min(estimatedHeight, 2000))
    }
}

// MARK: - List Content View
/// DUMB Component: Displays list places in grid, delegates actions via closures
/// Single Responsibility: Render place grid with pagination, delegate loading
struct ListContentView: View {
    let list: LightweightPlaceList
    @Binding var showOnlyUnvisited: Bool
    @Binding var isLoadingMore: Bool
    @Binding var hasMorePlaces: Bool
    @Binding var currentPage: Int
    let onLoadMore: () -> Void
    let onNavigateToPlace: ((String) -> Void)? // Navigation callback for NavigationStack
    
    @EnvironmentObject var profile: ProfileViewModel
    
    // Grid layout matching ProfileView lists (consistent spacing)
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    // Get all places for this list (from profile state)
    var allPlaces: [LightweightPlace] {
        return profile.lightweightPlaceListPlaces[list.list_id] ?? []
    }
    
    // Filtered places based on visited status (uses ViewModel's database-verified reviewed IDs)
    var filteredPlaces: [LightweightPlace] {
        let toFilter = showOnlyUnvisited ?
            allPlaces.filter { !profile.hasVerifiedReviewedPlace(placeId: $0.place_id) } :
            allPlaces

        // Secondary deduplication - eliminate any duplicates by place_id (defense in depth)
        var seenIds = Set<String>()
        return toFilter.filter { place in
            guard !seenIds.contains(place.place_id) else { return false }
            seenIds.insert(place.place_id)
            return true
        }
    }
    
    var body: some View {
        if !filteredPlaces.isEmpty {
            // Removed ScrollView wrapper - parent now handles scrolling
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(Array(filteredPlaces.enumerated()), id: \.element.id) { index, place in
                        LightweightPlaceGridCell(
                            place: place,
                            isCollaborativeList: list.isCollaborative,
                            onNavigateToPlace: onNavigateToPlace
                        )
                        .onAppear {
                            // Load more when user scrolls to 3rd-to-last item in FILTERED results
                            if index == filteredPlaces.count - 3 {
                                onLoadMore()
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            .padding(.top, 0)
            .padding(.bottom, 0)
                
                // Loading indicator at bottom
                if isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
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

// MARK: - Collaborator Avatars Button
// DUMB Component: Shows overlapping profile pictures for collaborators (like map annotations)
// Single Responsibility: Display compact avatar stack for list popup header

private struct CollaboratorAvatarsButton: View {
    let isSharedWithMe: Bool
    let ownerPhotoUrl: String?
    let collaboratorPhotos: [String]?
    
    private let avatarSize: CGFloat = 24
    private let maxAvatars = 3
    
    var body: some View {
        HStack(spacing: -8) {
            // Show owner avatar if this list is shared with you
            if isSharedWithMe, let ownerUrl = ownerPhotoUrl {
                avatarCircle(url: ownerUrl)
                    .zIndex(0)
            }
            
            // Collaborator avatars
            if let photos = collaboratorPhotos {
                let visibleCount = isSharedWithMe ? maxAvatars - 1 : maxAvatars
                
                ForEach(Array(photos.prefix(visibleCount).enumerated()), id: \.offset) { index, photoUrl in
                    avatarCircle(url: photoUrl)
                        .zIndex(Double(-index - 1))
                }
                
                // Overflow count badge
                if photos.count > visibleCount {
                    overflowBadge(count: photos.count - visibleCount)
                        .zIndex(-10)
                }
            }
        }
    }
    
    private func avatarCircle(url: String) -> some View {
        AsyncImage(url: URL(string: url)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure, .empty:
                placeholderCircle
            @unknown default:
                placeholderCircle
            }
        }
        .frame(width: avatarSize, height: avatarSize)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white, lineWidth: 2))
    }
    
    private var placeholderCircle: some View {
        Circle()
            .fill(Color(.systemGray4))
            .overlay(
                Text("?")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
            )
    }
    
    private func overflowBadge(count: Int) -> some View {
        Circle()
            .fill(Color(.systemGray4))
            .frame(width: avatarSize, height: avatarSize)
            .overlay(
                Text("+\(count)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.primary)
            )
            .overlay(Circle().stroke(Color.white, lineWidth: 2))
    }
}

// MARK: - Block Horizontal Swipe Modifier

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
            )
        )
    }
}
