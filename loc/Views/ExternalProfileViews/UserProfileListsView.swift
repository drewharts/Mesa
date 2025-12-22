//
//  UserProfileListsView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 5/29/25.
//


import SwiftUI

/// Displays a user's place lists with lazy loading
/// Single Responsibility: Renders list UI and binds to ViewModel state
struct UserProfileListsView: View {
    @ObservedObject var viewModel: UserProfileViewModel
    let placeLists: [LightweightPlaceList]
    
    @State private var placeColors: [UUID: Color] = [:]
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader
            listContent
        }
        .sheet(isPresented: $viewModel.shouldShowListPopup, onDismiss: {
            viewModel.onListPopupDismissed()
        }) {
            deepLinkListPopup
        }
    }
    
    // MARK: - View Components
    
    private var sectionHeader: some View {
        Text("Lists")
            .font(.headline)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 16)
            .foregroundColor(.primary)
    }
    
    @ViewBuilder
    private var listContent: some View {
        if placeLists.isEmpty {
            emptyState
        } else {
            listItems
        }
    }
    
    private var emptyState: some View {
        Text("No lists available")
            .font(.subheadline)
            .foregroundColor(.gray)
            .padding(.leading, 20)
    }
    
    // 2-column grid for displaying lists side by side
    private let listColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    private var listItems: some View {
        LazyVGrid(columns: listColumns, spacing: 16) {
            ForEach(placeLists, id: \.id) { list in
                UserProfileLightweightListSection(
                    viewModel: viewModel,
                    list: list,
                    places: viewModel.placeListPlaces[list.list_id] ?? [],
                    allLists: placeLists,
                    currentIndex: placeLists.firstIndex(where: { $0.id == list.id }) ?? 0,
                    placeColors: $placeColors
                )
                .onAppear {
                    handleListAppear(list)
                }
            }
            
            // Loading indicator for pagination
            if viewModel.isLoadingMoreLists {
                paginationLoadingIndicator
            }
        }
        .padding(.horizontal, 16)
    }
    
    private var paginationLoadingIndicator: some View {
        HStack {
            Spacer()
            ProgressView()
                .padding(.vertical, 16)
            Spacer()
        }
    }
    
    @ViewBuilder
    private var deepLinkListPopup: some View {
        if let index = viewModel.pendingListIndex, index < placeLists.count {
            ExternalUserLightweightListPopupView(
                viewModel: viewModel,
                lists: placeLists,
                initialListIndex: index,
                placeColors: $placeColors
            )
            .environmentObject(selectedPlaceVM)
        }
    }
    
    // MARK: - Event Handlers
    
    private func handleListAppear(_ list: LightweightPlaceList) {
        // Lazy load places for this list if not loaded yet
        if viewModel.placeListPlaces[list.list_id] == nil {
            viewModel.loadPlacesForList(list)
        }
        
        // Fetch more lists from backend when approaching the end
        if isNearEndOfLists(list) {
            viewModel.fetchMoreLists()
        }
    }
    
    /// Returns true if this list is near the end, triggering pagination
    private func isNearEndOfLists(_ list: LightweightPlaceList) -> Bool {
        guard placeLists.count >= 3 else { return false }
        guard let currentIndex = placeLists.firstIndex(where: { $0.id == list.id }) else { return false }
        
        // Trigger when viewing one of the last 3 items
        let threshold = placeLists.count - 3
        return currentIndex >= threshold
    }
}

/// Lightweight list section for external user profiles - similar to LightweightProfileListSection but for external users
/// Staff Engineer Refactor: Removed GeometryReader anti-pattern for stable LazyVGrid rendering
struct UserProfileLightweightListSection: View {
    @ObservedObject var viewModel: UserProfileViewModel
    let list: LightweightPlaceList
    let places: [LightweightPlace]
    let allLists: [LightweightPlaceList]
    let currentIndex: Int
    @Binding var placeColors: [UUID: Color]
    
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showingListPopup = false
    
    private var totalPlaceCount: Int {
        return list.place_count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Photo collage button
            Button(action: {
                showingListPopup = true
            }) {
                ExternalUserListCardImage(places: places, placeColors: $placeColors)
            }
            .buttonStyle(PlainButtonStyle())
            
            // List info
            VStack(alignment: .leading, spacing: 2) {
                Text(list.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text("\(totalPlaceCount) place\(totalPlaceCount == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showingListPopup) {
            ExternalUserLightweightListPopupView(
                viewModel: viewModel,
                lists: allLists,
                initialListIndex: currentIndex,
                placeColors: $placeColors
            )
            .environmentObject(selectedPlaceVM)
        }
    }
}

// MARK: - External User List Card Image
/// Square image card for external user list preview - NO GeometryReader needed!
private struct ExternalUserListCardImage: View {
    let places: [LightweightPlace]
    @Binding var placeColors: [UUID: Color]
    
    var body: some View {
        Group {
            if !places.isEmpty {
                ListPhotoCollage(
                    places: Array(places.prefix(3)),
                    placeColors: $placeColors
                )
            } else {
                ExternalUserEmptyListCard()
            }
        }
        .aspectRatio(1, contentMode: .fit) // Square sizing - no measurement needed!
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
    }
}

// MARK: - External User Empty List Card
private struct ExternalUserEmptyListCard: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 24))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No places yet")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
}

/// Lightweight place preview card for external user profiles
/// Note: These small preview tiles are NOT clickable - only tiles in the full popup are clickable
struct UserProfileLightweightPlacePreviewCard: View {
    let place: LightweightPlace
    @Binding var placeColors: [UUID: Color]
    var height: CGFloat = 80  // Default height, can be customized for compact layouts
    
    // Generate a consistent color for this place based on its ID
    private var placeColor: Color {
        let hash = place.place_id.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.8)
    }
    
    // Smaller corner radius for compact views
    private var cornerRadius: CGFloat {
        height < 80 ? 6 : 8
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Container to strictly enforce bounds
            Rectangle()
                .fill(Color.clear)
                .frame(height: height)
                .overlay(
                    Group {
                        // Check for TikTok thumbnail first, then review photo, then colored rectangle
                        if let tiktokUrl = place.tiktok_url,
                           let thumbnailURL = TikTokMetadataCache.shared.getCachedThumbnailUrl(for: tiktokUrl) {
                            AsyncImage(url: URL(string: thumbnailURL)) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(maxWidth: .infinity, maxHeight: height)
                                        .clipped()
                                case .failure:
                                    Rectangle()
                                        .foregroundColor(placeColor)
                                        .frame(maxWidth: .infinity, maxHeight: height)
                                case .empty:
                                    Rectangle()
                                        .foregroundColor(.gray.opacity(0.3))
                                        .frame(maxWidth: .infinity, maxHeight: height)
                                        .onAppear {
                                            Task {
                                                _ = await TikTokMetadataCache.shared.getMetadata(for: tiktokUrl)
                                            }
                                        }
                                @unknown default:
                                    Rectangle()
                                        .foregroundColor(placeColor)
                                        .frame(maxWidth: .infinity, maxHeight: height)
                                }
                            }
                        } else if let photoUrl = place.latest_review_photo, let url = URL(string: photoUrl) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(maxWidth: .infinity, maxHeight: height)
                                        .clipped()
                                case .failure:
                                    Rectangle()
                                        .foregroundColor(placeColor)
                                        .frame(maxWidth: .infinity, maxHeight: height)
                                case .empty:
                                    Rectangle()
                                        .foregroundColor(.gray.opacity(0.3))
                                        .frame(maxWidth: .infinity, maxHeight: height)
                                @unknown default:
                                    Rectangle()
                                        .foregroundColor(placeColor)
                                        .frame(maxWidth: .infinity, maxHeight: height)
                                }
                            }
                        } else {
                            Rectangle()
                                .foregroundColor(placeColor)
                                .frame(maxWidth: .infinity, maxHeight: height)
                                .onAppear {
                                    if let tiktokUrl = place.tiktok_url {
                                        Task {
                                            _ = await TikTokMetadataCache.shared.getMetadata(for: tiktokUrl)
                                        }
                                    }
                                }
                        }
                    }
                    .clipped()
                )
            
            // Gradient overlay for text readability
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.0),
                    Color.black.opacity(0.1),
                    Color.black.opacity(0.2),
                    Color.black.opacity(1.0)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: height)
            
            // Text overlay
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: height)
        .clipped()
        .cornerRadius(cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        // Small preview tiles are NOT clickable - only tiles in the full popup are clickable
    }
}

/// Lightweight list popup view for external user profiles - matches MyProfile's popup exactly
struct ExternalUserLightweightListPopupView: View {
    @ObservedObject var viewModel: UserProfileViewModel
    let lists: [LightweightPlaceList]
    let initialListIndex: Int
    @Binding var placeColors: [UUID: Color]
    
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var currentListIndex: Int
    @State private var isLoadingMore: Bool = false
    @State private var hasMorePlaces: Bool = true
    @State private var currentPage: Int = 1
    
    private let cardWidth: CGFloat = UIScreen.main.bounds.width / 2 - 35
    private let cardHeight: CGFloat = 180
    
    private let columns = [
        GridItem(.flexible(), spacing: 15),
        GridItem(.flexible(), spacing: 15)
    ]
    
    init(viewModel: UserProfileViewModel, lists: [LightweightPlaceList], initialListIndex: Int, placeColors: Binding<[UUID: Color]>) {
        self.viewModel = viewModel
        self.lists = lists
        self.initialListIndex = initialListIndex
        self._placeColors = placeColors
        self._currentListIndex = State(initialValue: initialListIndex)
    }
    
    private var currentList: LightweightPlaceList {
        lists[currentListIndex]
    }
    
    private var places: [LightweightPlace] {
        viewModel.placeListPlaces[currentList.list_id] ?? []
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with list name and controls
                VStack(spacing: 12) {
                    // Top bar with close button
                    HStack {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
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
                        
                        // Show list counter if multiple lists
                        if lists.count > 1 {
                            Text("\(currentListIndex + 1) of \(lists.count)")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 10)
                
                // Content with swiping support
                if lists.count > 1 {
                    // Multiple lists - use TabView for swiping
                    TabView(selection: $currentListIndex) {
                        ForEach(lists.indices, id: \.self) { index in
                            ExternalUserListContentView(
                                list: lists[index],
                                placeColors: $placeColors,
                                viewModel: viewModel,
                                cardWidth: cardWidth,
                                cardHeight: cardHeight
                            )
                            .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .onChange(of: currentListIndex) { _, newIndex in
                        // Load places for new list if needed
                        loadPlacesIfNeeded()
                    }
                } else {
                    // Single list - no swiping needed
                    ExternalUserListContentView(
                        list: currentList,
                        placeColors: $placeColors,
                        viewModel: viewModel,
                        cardWidth: cardWidth,
                        cardHeight: cardHeight
                    )
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            // Load places for the current list
            loadPlacesIfNeeded()
        }
    }
    
    private func loadPlacesIfNeeded() {
        let list = lists[currentListIndex]
        if viewModel.placeListPlaces[list.list_id] == nil {
            viewModel.loadPlacesForList(list)
        }
    }
}

/// List content view for external users - matches MyProfile's ListContentView
struct ExternalUserListContentView: View {
    let list: LightweightPlaceList
    @Binding var placeColors: [UUID: Color]
    @ObservedObject var viewModel: UserProfileViewModel
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    
    private let columns = [
        GridItem(.flexible(), spacing: 15),
        GridItem(.flexible(), spacing: 15)
    ]
    
    var places: [LightweightPlace] {
        viewModel.placeListPlaces[list.list_id] ?? []
    }
    
    var body: some View {
        if !places.isEmpty {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 15) {
                    ForEach(places, id: \.id) { place in
                        ExternalUserListPlaceCard(
                            place: place,
                            cardWidth: cardWidth,
                            cardHeight: cardHeight,
                            placeColors: $placeColors
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
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

/// Card-based place view for external user list popup - matches LightweightPlaceGridCell exactly
struct ExternalUserListPlaceCard: View {
    let place: LightweightPlace
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    @Binding var placeColors: [UUID: Color]
    
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    @Environment(\.presentationMode) var presentationMode
    
    // Generate a consistent color for this place based on its ID
    private var placeColor: Color {
        let hash = place.place_id.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.8)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottom) {
                // Check for TikTok thumbnail first, then review photo, then colored rectangle
                if let tiktokUrl = place.tiktok_url,
                   let thumbnailURL = TikTokMetadataCache.shared.getCachedThumbnailUrl(for: tiktokUrl) {
                    // Show TikTok thumbnail with proper phase handling
                    AsyncImage(url: URL(string: thumbnailURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: cardWidth, height: cardHeight)
                                .clipped()
                        case .failure:
                            Rectangle()
                                .foregroundColor(placeColor)
                                .frame(width: cardWidth, height: cardHeight)
                        case .empty:
                            Rectangle()
                                .foregroundColor(placeColor)
                                .frame(width: cardWidth, height: cardHeight)
                                .overlay(
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                )
                                .onAppear {
                                    // Prefetch TikTok metadata if not cached
                                    Task {
                                        _ = await TikTokMetadataCache.shared.getMetadata(for: tiktokUrl)
                                    }
                                }
                        @unknown default:
                            Rectangle()
                                .foregroundColor(placeColor)
                                .frame(width: cardWidth, height: cardHeight)
                        }
                    }
                } else if let photoUrl = place.latest_review_photo, let url = URL(string: photoUrl) {
                    // Show review photo with proper phase handling
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: cardWidth, height: cardHeight)
                                .clipped()
                        case .failure:
                            Rectangle()
                                .foregroundColor(placeColor)
                                .frame(width: cardWidth, height: cardHeight)
                        case .empty:
                            Rectangle()
                                .foregroundColor(placeColor)
                                .frame(width: cardWidth, height: cardHeight)
                                .overlay(
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                )
                        @unknown default:
                            Rectangle()
                                .foregroundColor(placeColor)
                                .frame(width: cardWidth, height: cardHeight)
                        }
                    }
                } else {
                    // No photo - show colored background
                    Rectangle()
                        .foregroundColor(placeColor)
                        .frame(width: cardWidth, height: cardHeight)
                        .onAppear {
                            // If we have a TikTok URL but no cached thumbnail, prefetch it
                            if let tiktokUrl = place.tiktok_url {
                                Task {
                                    _ = await TikTokMetadataCache.shared.getMetadata(for: tiktokUrl)
                                }
                            }
                        }
                }
                
                // Gradient overlay
                LinearGradient(
                    gradient: Gradient(colors: [.clear, .black.opacity(0.7)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: cardWidth, height: cardHeight)
                
                // Place name
                Text(place.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .onTapGesture {
            Task {
                await loadPlaceAndNavigate()
            }
        }
    }
    
    private func loadPlaceAndNavigate() async {
        do {
            let detailPlace = try await PlaceService.shared.fetchPlace(withId: place.place_id)
            await MainActor.run {
                // Dismiss the list popup sheet first
                presentationMode.wrappedValue.dismiss()
                
                // Use centralized navigation method from UserProfileViewModel
                userProfileViewModel.navigateToPlaceFromProfile(detailPlace, selectedPlaceVM: selectedPlaceVM)
            }
        } catch {
            print("❌ Error loading place details: \(error)")
        }
    }
}

