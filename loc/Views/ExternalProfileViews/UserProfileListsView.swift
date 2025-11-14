//
//  UserProfileListsView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 5/29/25.
//


import SwiftUI

struct UserProfileListsView: View {
    @ObservedObject var viewModel: UserProfileViewModel
    var placeLists: [LightweightPlaceList]
    @State private var placeColors: [UUID: Color] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("LISTS")
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 20)
                .foregroundStyle(.black)

            if placeLists.isEmpty {
                Text("No lists available")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.leading, 20)
            } else {
                LazyVStack(spacing: 16) {
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
                            // Lazy load places for this list if not loaded yet
                            if viewModel.placeListPlaces[list.list_id] == nil {
                                viewModel.loadPlacesForList(list)
                            }
                            
                            // Load more lists when approaching the end
                            if let lastThreeIndex = placeLists.dropLast(3).lastIndex(where: { $0.id == list.id }),
                               lastThreeIndex == placeLists.index(placeLists.endIndex, offsetBy: -3) {
                                viewModel.loadMoreListsIfNeeded()
                            }
                        }
                    }
                }
            }
        }
    }
}

/// Lightweight list section for external user profiles - similar to LightweightProfileListSection but for external users
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
    
    // Get total place count from the list (from SQL function)
    private var totalPlaceCount: Int {
        return list.place_count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // List header with title and place count
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(list.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("\(totalPlaceCount) place\(totalPlaceCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // Card with places grid
            Button(action: {
                showingListPopup = true
            }) {
                VStack(spacing: 0) {
                    if !places.isEmpty {
                        // Places grid (first 6 places in 2x3 layout)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                            ForEach(Array(places.prefix(6).enumerated()), id: \.element.id) { index, place in
                                UserProfileLightweightPlacePreviewCard(
                                    place: place,
                                    placeColors: $placeColors
                                )
                                .environmentObject(viewModel)
                            }
                            
                            // Fill remaining slots if less than 6 places
                            if places.count < 6 {
                                ForEach(0..<(6 - places.count), id: \.self) { _ in
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.1))
                                        .frame(height: 80)
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                        )
                                }
                            }
                        }
                        .padding(16)
                    } else {
                        // Empty state
                        VStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 32))
                                .foregroundColor(.gray.opacity(0.5))
                            
                            Text("No places yet")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            Text("This list doesn't have any places yet")
                                .font(.caption)
                                .foregroundColor(.gray.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .frame(height: 120)
                        .frame(maxWidth: .infinity)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .scaleEffect(1.0)
        }
        .padding(.horizontal, 20)
        .sheet(isPresented: $showingListPopup) {
            // Use the same lightweight popup as MyProfile - need to pass profile data
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

/// Lightweight place preview card for external user profiles
/// Note: These small preview tiles are NOT clickable - only tiles in the full popup are clickable
struct UserProfileLightweightPlacePreviewCard: View {
    let place: LightweightPlace
    @Binding var placeColors: [UUID: Color]
    
    // Generate a consistent color for this place based on its ID
    private var placeColor: Color {
        let hash = place.place_id.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.8)
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Container to strictly enforce bounds
            Rectangle()
                .fill(Color.clear)
                .frame(height: 80)
                .overlay(
                    Group {
                        // Check for TikTok thumbnail first, then review photo, then colored rectangle
                        if let tiktokUrl = place.tiktok_url,
                           let thumbnailURL = TikTokMetadataCache.shared.getCachedThumbnailUrl(for: tiktokUrl) {
                            AsyncImage(url: URL(string: thumbnailURL)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(maxWidth: .infinity, maxHeight: 80)
                                    .clipped()
                            } placeholder: {
                                Rectangle()
                                    .foregroundColor(.gray.opacity(0.3))
                                    .frame(maxWidth: .infinity, maxHeight: 80)
                                    .onAppear {
                                        Task {
                                            _ = await TikTokMetadataCache.shared.getMetadata(for: tiktokUrl)
                                        }
                                    }
                            }
                        } else if let photoUrl = place.latest_review_photo, let url = URL(string: photoUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(maxWidth: .infinity, maxHeight: 80)
                                    .clipped()
                            } placeholder: {
                                Rectangle()
                                    .foregroundColor(.gray.opacity(0.3))
                                    .frame(maxWidth: .infinity, maxHeight: 80)
                            }
                        } else {
                            Rectangle()
                                .foregroundColor(placeColor)
                                .frame(maxWidth: .infinity, maxHeight: 80)
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
            .frame(height: 80)
            
            // Text overlay
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 80)
        .clipped()
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
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
                    // Show TikTok thumbnail
                    AsyncImage(url: URL(string: thumbnailURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: cardWidth, height: cardHeight)
                            .clipped()
                    } placeholder: {
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
                    }
                } else if let photoUrl = place.latest_review_photo, let url = URL(string: photoUrl) {
                    // Show review photo
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: cardWidth, height: cardHeight)
                            .clipped()
                    } placeholder: {
                        Rectangle()
                            .foregroundColor(placeColor)
                            .frame(width: cardWidth, height: cardHeight)
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            )
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
                
                // Then navigate to map and select place
                selectedPlaceVM.navigateToMapAndSelectPlace(detailPlace) {
                    // Dismiss user profile navigation
                    userProfileViewModel.isUserDetailPresented = false
                }
            }
        } catch {
            print("❌ Error loading place details: \(error)")
        }
    }
}

