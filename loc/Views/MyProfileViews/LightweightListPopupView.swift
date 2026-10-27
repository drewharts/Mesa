//
//  LightweightListPopupView.swift
//  loc
//
//  Created by Claude on 1/20/25.
//

import SwiftUI
import Combine

struct LightweightListPopupView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel

    /// Observed for pending place navigation when map annotation is tapped while sheet is open.
    @ObservedObject private var presentationService = PresentationService.shared

    /// Per-list pagination state management.
    @StateObject private var paginationVM = ListPopupPaginationViewModel()
    @StateObject private var storyViewModel = ListStoryCardViewModel()

    /// Map-first coordination: sheet height, focused place, camera requests.
    @ObservedObject private var sheetVM = ListMapSheetViewModel.shared
    /// Category/neighborhood line data for rows.
    @ObservedObject private var placeMeta = ListPlaceMetaStore.shared

    let lists: [LightweightPlaceList]
    let initialListIndex: Int

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
    @State private var showEditListSheet: Bool = false
    @State private var navigationPath = NavigationPath() // Navigation path for place detail navigation
    @State private var hasInitiallyAppeared = false

    // Convenience initializer for single list (backward compatibility)
    init(list: LightweightPlaceList, listsVM: ProfileListsViewModel, reviewsVM: ProfileReviewsViewModel, places: [LightweightPlace] = []) {
        self.lists = [list]
        self.initialListIndex = 0
        self._currentListIndex = State(initialValue: 0)
        self.listsVM = listsVM
        self.reviewsVM = reviewsVM
    }

    // Initializer for multiple lists with swiping
    init(lists: [LightweightPlaceList], initialListIndex: Int, listsVM: ProfileListsViewModel, reviewsVM: ProfileReviewsViewModel) {
        self.lists = lists
        self.initialListIndex = initialListIndex
        self._currentListIndex = State(initialValue: initialListIndex)
        self.listsVM = listsVM
        self.reviewsVM = reviewsVM
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
                city: nil,
                description: nil
            )
        }
        return lists[currentListIndex]
    }

    // Get all places for the current list (from profile state) - used for filtering logic
    var allPlaces: [LightweightPlace] {
        return listsVM.lightweightPlaceListPlaces[currentList.list_id] ?? []
    }

    /// Looks up a place of the current list by id (case-insensitive).
    private func place(withId placeId: String) -> LightweightPlace? {
        allPlaces.first { $0.place_id.caseInsensitiveCompare(placeId) == .orderedSame }
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

                // Place rows scroll below the header
                contentSection
            }
            .navigationBarHidden(true)
            .navigationDestination(for: String.self) { placeId in
                // Navigate to place detail when place ID is pushed onto path
                // .id(placeId) forces full view re-creation when the path is replaced
                // with a different placeId, ensuring @StateObject re-initializes
                PlaceDetailViewInNavigation(placeId: placeId, minSheetHeight: 250, shouldAnimateMap: true)
                    .id(placeId)
            }
        }
        .onReceive(presentationService.$pendingPlaceNavigation.compactMap { $0 }) { placeId in
            // When a map pin is tapped while the list sheet is open, highlight and scroll to its row.
            // Uses onReceive (Combine) instead of onChange for reliable delivery even when
            // a navigation destination is pushed on the stack.
            presentationService.pendingPlaceNavigation = nil
            handleMapPinTap(placeId)
        }
        .onAppear {
            // Clear navigation path only on the first appearance (when the sheet opens).
            // Guard prevents this from interfering if onAppear re-fires during navigation transitions.
            guard !hasInitiallyAppeared else { return }
            hasInitiallyAppeared = true
            navigationPath = NavigationPath()

            // Set dependencies for pagination ViewModel
            paginationVM.setDependencies(listsVM: listsVM, reviewsVM: reviewsVM)

            // Start the map-first session (resets height/focus, tracks the open)
            sheetVM.beginSession(
                listId: currentList.list_id,
                placeCount: displayedPlaceCount,
                isExternal: false,
                source: "map_sheet"
            )

            // Load the first page, then the rest so every pin has a row, then fit the map to the pins
            Task {
                await listsVM.loadPlacesForListIfNeeded(listId: currentList.list_id, fallbackCount: currentList.place_count)
                await loadFullListAndFitMap()
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
            placeMeta.prefetchCities(for: newValue)
        }
        .onDisappear {
            sheetVM.endSession()
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
                initialIsPublic: currentList.is_public,
                currentPriceTier: currentList.price_tier
            )
            .presentationDetents([.medium])
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
        .sheet(isPresented: $showEditListSheet) {
            EditListSheet(
                listId: currentList.list_id,
                currentName: currentList.name,
                currentDescription: currentList.description,
                onSave: { newName, newDescription in
                    Task {
                        if newName != currentList.name {
                            _ = await listsVM.renameList(currentList, newName: newName)
                        }
                        let currentDesc = currentList.description ?? ""
                        let newDesc = newDescription ?? ""
                        if newDesc != currentDesc {
                            _ = await listsVM.updateListDescription(currentList, rawText: newDesc)
                        }
                    }
                }
            )
            .presentationDetents([.height(300)])
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
                        .foregroundColor(.primary)

                    Spacer()

                    // Action buttons: overflow menu
                    if let userId = profile.user?.id {
                        HStack(alignment: .center, spacing: 12) {
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
                                        showEditListSheet = true
                                    } label: {
                                        Label("Edit List", systemImage: "pencil")
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

                if let description = currentList.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            
        }
        .padding(.bottom, 8)
    }
    
    /// Content section displaying the current list's places as rows.
    /// Single Responsibility: Display list content, delegate selection to the map-first view model.
    private var contentSection: some View {
        let listId = currentList.list_id
        let paginationState = paginationVM.state(for: listId)
        let isLoadingInitial = listsVM.isLoadingInitialPlaces(listId: listId)
            || (allPlaces.isEmpty && paginationState.isLoadingMore)
        return ListPlacesScrollView(
            places: allPlaces,
            isLoadingInitial: isLoadingInitial,
            isLoadingMore: paginationState.isLoadingMore && !allPlaces.isEmpty,
            showAddedBy: currentList.isCollaborative,
            focusedPlaceId: sheetVM.focusedPlaceId,
            scrollRequest: sheetVM.scrollRequest,
            locationText: { placeMeta.location(for: $0) },
            onRowAppear: { placeMeta.requestNeighborhood(for: $0) },
            onLoadMore: { paginationVM.loadMoreIfNeeded(for: listId) },
            onSelect: { handleRowTap($0) },
            onOpenDetail: { openPlaceDetail($0) },
            onRemove: { placeId in
                profile.listsViewModel.removePlaceFromLightweightList(listId: listId, placeId: placeId)
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Map-First Actions

    /// Loads every place of the list, then fits the map to all pins and warms the location lines.
    private func loadFullListAndFitMap() async {
        await paginationVM.loadAllPlaces(for: currentList.list_id, expectedCount: displayedPlaceCount)
        sheetVM.fitToPlaces(allPlaces)
        placeMeta.prefetchCities(for: allPlaces)
    }

    /// Row tap: highlight and center its pin. Tapping the already-selected row opens its details.
    private func handleRowTap(_ place: LightweightPlace) {
        if sheetVM.isFocused(place.place_id) {
            openPlaceDetail(place)
        } else {
            sheetVM.focus(place: place, source: .row)
        }
    }

    /// Opens the place page inside the sheet.
    private func openPlaceDetail(_ place: LightweightPlace) {
        sheetVM.ensureAtLeastHalf()
        navigationPath.append(place.place_id)
    }

    /// Pin tap: scroll to and highlight the row; a second tap on the same pin opens its details.
    /// While a place page is open, a pin tap swaps to that place (previous behavior).
    private func handleMapPinTap(_ placeId: String) {
        let isShowingDetail = !navigationPath.isEmpty
        guard let tapped = place(withId: placeId) else {
            var newPath = NavigationPath()
            newPath.append(placeId)
            navigationPath = newPath
            return
        }
        if isShowingDetail {
            // Swap the open place page to the tapped pin's place.
            sheetVM.focus(place: tapped, source: .pin)
            replaceDetail(with: tapped.place_id)
        } else if sheetVM.isFocused(tapped.place_id) {
            replaceDetail(with: tapped.place_id)
        } else {
            sheetVM.focus(place: tapped, source: .pin)
        }
    }

    /// Replaces the navigation stack with a single place page.
    private func replaceDetail(with placeId: String) {
        sheetVM.ensureAtLeastHalf()
        var newPath = NavigationPath()
        newPath.append(placeId)
        navigationPath = newPath
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
