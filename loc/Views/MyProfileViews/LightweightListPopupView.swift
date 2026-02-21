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

    /// Observed for pending place navigation when map annotation is tapped while sheet is open.
    @ObservedObject private var presentationService = PresentationService.shared

    /// Per-list pagination state management.
    @StateObject private var paginationVM = ListPopupPaginationViewModel()
    @StateObject private var storyViewModel = ListStoryCardViewModel()

    let lists: [LightweightPlaceList]
    let initialListIndex: Int
    let onViewOnMap: (() -> Void)?

    @ObservedObject var listsVM: ProfileListsViewModel
    @ObservedObject var reviewsVM: ProfileReviewsViewModel

    @State private var currentListIndex: Int
    @State private var showCollaboratorsSheet: Bool = false
    @State private var showSettingsSheet: Bool = false
    @State private var showAddPlaceSheet: Bool = false
    @State private var showPhotoSelector: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    @State private var showDeleteError: Bool = false
    @State private var deleteErrorMessage: String = ""
    @State private var showRenameAlert: Bool = false
    @State private var renameText: String = ""
    @State private var showRenameError: Bool = false
    @State private var renameErrorMessage: String = ""
    @State private var navigationPath = NavigationPath() // Navigation path for place detail navigation

    // Convenience initializer for single list (backward compatibility)
    init(list: LightweightPlaceList, listsVM: ProfileListsViewModel, reviewsVM: ProfileReviewsViewModel, places: [LightweightPlace] = [], onViewOnMap: (() -> Void)? = nil) {
        self.lists = [list]
        self.initialListIndex = 0
        self._currentListIndex = State(initialValue: 0)
        self.listsVM = listsVM
        self.reviewsVM = reviewsVM
        self.onViewOnMap = onViewOnMap
    }

    // Initializer for multiple lists with swiping
    init(lists: [LightweightPlaceList], initialListIndex: Int, listsVM: ProfileListsViewModel, reviewsVM: ProfileReviewsViewModel, onViewOnMap: (() -> Void)? = nil) {
        self.lists = lists
        self.initialListIndex = initialListIndex
        self._currentListIndex = State(initialValue: initialListIndex)
        self.listsVM = listsVM
        self.reviewsVM = reviewsVM
        self.onViewOnMap = onViewOnMap
    }

    // Current list being displayed (uses passed lists, not profile.lightweightPlaceLists for filtered support)
    private var currentList: LightweightPlaceList {
        guard currentListIndex >= 0 && currentListIndex < lists.count else {
            return lists.first ?? LightweightPlaceList(
                list_id: "",
                name: "Unknown",
                is_public: true,
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
        return listsVM.lightweightPlaceListPlaces[currentList.list_id] ?? []
    }

    /// Reactive place count that reflects optimistic cache updates, not the stale snapshot.
    private var displayedPlaceCount: Int {
        listsVM.lightweightPlaceListCounts[currentList.list_id] ?? currentList.place_count
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // Header fixed at top, not scrollable
                headerSection

                // Content scrolls vertically
                ScrollView {
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
        .onChange(of: presentationService.pendingPlaceNavigation) { oldValue, newValue in
            // When map annotation is tapped while list sheet is open, navigate to that place
            // MVVM: View coordinates navigation based on PresentationService state
            // This makes annotation taps behave the same as clicking a place tile in the list sheet
            if let placeId = newValue {
                navigationPath.append(placeId)
                // Clear the pending navigation after handling it
                presentationService.pendingPlaceNavigation = nil
            }
        }
        .onAppear {
            // Clear navigation path when sheet appears (ensures fresh state each time)
            // MVVM: View manages its own navigation state - reset on each presentation
            // Best Practice: Clear in onAppear rather than onDisappear for reliability
            navigationPath = NavigationPath()

            // Set dependencies for pagination ViewModel
            paginationVM.setDependencies(listsVM: listsVM, reviewsVM: reviewsVM)

            // Load places for the current list if not already fully cached
            Task {
                await listsVM.loadPlacesForListIfNeeded(listId: currentList.list_id, fallbackCount: currentList.place_count)
            }

            // Initialize pagination state and load reviewed IDs via ViewModel
            Task {
                await paginationVM.onListChanged(to: currentList.list_id)
            }
        }
        .onChange(of: allPlaces) { oldValue, newValue in
            // Reload reviewed IDs when places change via ViewModel
            Task {
                await paginationVM.onListChanged(to: currentList.list_id)
            }
        }
        .sheet(isPresented: $showCollaboratorsSheet) {
            if let userId = profile.user?.id {
                ManageCollaboratorsSheet(
                    listId: currentList.list_id,
                    currentUserId: userId
                )
            }
        }
        .sheet(isPresented: $showSettingsSheet) {
            ListSettingsSheet(
                listId: currentList.list_id,
                initialIsPublic: currentList.is_public
            )
            .presentationDetents([.height(200)])
        }
        .sheet(isPresented: $showAddPlaceSheet) {
            if let userId = profile.user?.id {
                AddPlaceToListSheet(
                    listId: currentList.list_id,
                    listName: currentList.name,
                    userId: userId,
                    onPlaceAdded: { _, place in
                        // Optimistically insert the place into the local cache
                        listsVM.addPlaceToLightweightList(listId: currentList.list_id, place: place)
                    }
                )
            }
        }
        .sheet(isPresented: $showPhotoSelector) {
            StoryPhotoSelectorView(
                viewModel: storyViewModel,
                onShareInstagram: {
                    if let userId = profile.user?.id {
                        shareToInstagram(userId: userId)
                    }
                },
                onShareGeneral: {
                    if let userId = profile.user?.id {
                        shareGeneral(userId: userId)
                    }
                }
            )
            .presentationDetents([.medium, .large])
        }
        .alert("Link Copied!", isPresented: $storyViewModel.showLinkCopiedInstruction) {
            Button("Got it", role: .cancel) { }
        } message: {
            Text("Tap the sticker icon in Instagram, select \"Link\", and paste to add a clickable link to your story.")
        }
        .alert("Delete List", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    let result = await listsVM.deleteLightweightList(currentList)
                    switch result {
                    case .success:
                        presentationMode.wrappedValue.dismiss()
                    case .failure(let error):
                        deleteErrorMessage = error.localizedDescription
                        showDeleteError = true
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete \"\(currentList.name)\"? This action cannot be undone.")
        }
        .alert("Unable to Delete", isPresented: $showDeleteError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(deleteErrorMessage)
        }
        .alert("Rename List", isPresented: $showRenameAlert) {
            TextField("List name", text: $renameText)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                let trimmed = renameText.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                Task {
                    let result = await listsVM.renameList(currentList, newName: trimmed)
                    if case .failure(let error) = result {
                        renameErrorMessage = error.localizedDescription
                        showRenameError = true
                    }
                }
            }
        } message: {
            Text("Enter a new name for this list.")
        }
        .alert("Unable to Rename", isPresented: $showRenameError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(renameErrorMessage)
        }
    }

    // MARK: - View Components
    
    /// Header section with list name, place count, and action buttons.
    /// Single Responsibility: Display list header UI
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Top bar with list title and buttons aligned, place count below
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    Text(currentList.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.black)

                    Spacer()

                    // Action buttons: map and overflow menu
                    if let userId = profile.user?.id {
                        HStack(alignment: .center, spacing: 12) {
                            // View on Map button (profile popups only)
                            if let viewOnMap = onViewOnMap {
                                Button(action: viewOnMap) {
                                    Image(systemName: "map")
                                        .font(.system(size: 20, weight: .regular))
                                        .foregroundColor(.primary)
                                }
                                .frame(width: 44, height: 44)
                            }

                            // Overflow menu consolidating add, share, and settings actions
                            Menu {
                                Button {
                                    showAddPlaceSheet = true
                                } label: {
                                    Label("Add Place", systemImage: "mappin.and.ellipse")
                                }

                                Button {
                                    showCollaboratorsSheet = true
                                } label: {
                                    Label("Add Collaborator", systemImage: "person.badge.plus")
                                }

                                Divider()

                                Button {
                                    shareLink(userId: userId)
                                } label: {
                                    Label("Share Link", systemImage: "link")
                                }

                                Button {
                                    prepareAndShowPhotoSelector()
                                } label: {
                                    Label("Create Story Card", systemImage: "camera.fill")
                                }

                                if currentList.user_role == "owner" || !currentList.isSharedWithMe {
                                    Divider()

                                    Button {
                                        renameText = currentList.name
                                        showRenameAlert = true
                                    } label: {
                                        Label("Rename List", systemImage: "pencil")
                                    }

                                    Button {
                                        showSettingsSheet = true
                                    } label: {
                                        Label("List Settings", systemImage: "gearshape")
                                    }

                                    Button(role: .destructive) {
                                        showDeleteConfirmation = true
                                    } label: {
                                        Label("Delete List", systemImage: "trash")
                                    }
                                }
                            } label: {
                                ZStack {
                                    if storyViewModel.isGenerating {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                                    } else {
                                        Image(systemName: "ellipsis")
                                            .font(.system(size: 20, weight: .regular))
                                            .foregroundColor(.primary)
                                    }
                                }
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                            }
                            .disabled(storyViewModel.isGenerating)
                        }
                    }
                }

                Text("\(displayedPlaceCount) place\(displayedPlaceCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top, -8)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            
        }
        .padding(.bottom, 28)
    }
    
    /// Content section displaying the current list's places.
    /// Single Responsibility: Display list content without horizontal swiping.
    private var contentSection: some View {
        let listId = currentList.list_id
        let paginationState = paginationVM.state(for: listId)
        return VStack(alignment: .leading, spacing: 0) {
            ListContentView(
                list: currentList,
                isLoadingMore: paginationState.isLoadingMore,
                hasMorePlaces: paginationState.hasMorePlaces,
                onLoadMore: { paginationVM.loadMoreIfNeeded(for: listId) },
                onNavigateToPlace: { placeId in
                    navigationPath.append(placeId)
                },
                onRemovePlace: { placeId in
                    profile.listsViewModel.removePlaceFromLightweightList(listId: listId, placeId: placeId)
                },
                listsVM: listsVM,
                reviewsVM: reviewsVM
            )
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    // MARK: - Share Helpers

    /// Shares the list link via system share sheet.
    private func shareLink(userId: String) {
        ServiceContainer.shared.placeShareService.shareLightweightList(currentList, userId: userId)
    }

    /// Prepares photo options and shows the photo selector sheet.
    private func prepareAndShowPhotoSelector() {
        Task {
            await storyViewModel.preparePhotoOptions(places: allPlaces)
            showPhotoSelector = true
        }
    }

    /// Shares the story card to Instagram Stories.
    private func shareToInstagram(userId: String) {
        Task {
            await storyViewModel.shareToInstagram(
                list: currentList,
                places: allPlaces,
                userId: userId
            )
        }
    }

    /// Shares the story card via system share sheet.
    private func shareGeneral(userId: String) {
        Task {
            await storyViewModel.shareGeneral(
                list: currentList,
                places: allPlaces,
                userId: userId,
                shareService: ServiceContainer.shared.placeShareService
            )
        }
    }
}

// MARK: - List Content View
/// DUMB Component: Displays list places in grid, delegates actions via closures
/// Single Responsibility: Render place grid with pagination, delegate loading
struct ListContentView: View {
    let list: LightweightPlaceList
    let isLoadingMore: Bool
    let hasMorePlaces: Bool
    let onLoadMore: () -> Void
    let onNavigateToPlace: ((String) -> Void)?
    let onRemovePlace: ((String) -> Void)?

    @ObservedObject var listsVM: ProfileListsViewModel
    @ObservedObject var reviewsVM: ProfileReviewsViewModel

    // Grid layout matching ProfileView lists (consistent spacing)
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    /// Returns all places for this list from profile state.
    var allPlaces: [LightweightPlace] {
        return listsVM.lightweightPlaceListPlaces[list.list_id] ?? []
    }

    /// Returns deduplicated places for this list.
    var filteredPlaces: [LightweightPlace] {
        var seenIds = Set<String>()
        return allPlaces.filter { place in
            guard !seenIds.contains(place.place_id) else { return false }
            seenIds.insert(place.place_id)
            return true
        }
    }

    var body: some View {
        if !filteredPlaces.isEmpty {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(Array(filteredPlaces.enumerated()), id: \.element.id) { index, place in
                    PopupPlaceCard(
                        place: place,
                        preferExternalThumbnail: true,
                        onNavigate: onNavigateToPlace,
                        showAddedBy: list.isCollaborative
                    )
                    .contextMenu {
                        if let onRemovePlace {
                            Button(role: .destructive) {
                                onRemovePlace(place.place_id)
                            } label: {
                                Label("Remove from list", systemImage: "trash")
                            }
                        }
                    }
                    .onAppear {
                        // Load more when user scrolls to 3rd-to-last item
                        if index == filteredPlaces.count - 3 {
                            onLoadMore()
                        }
                    }
                }
            }
            .padding(.horizontal, 16)

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
                Text("No places in this list")
                    .foregroundColor(.gray)
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
