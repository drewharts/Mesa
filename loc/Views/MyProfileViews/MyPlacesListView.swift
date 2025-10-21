import SwiftUI
import UIKit

struct MyPlacesListView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var placeColors: [UUID: Color] = [:]
    @State private var selectedTab = 0
    @State private var showPageIndicators = true
    @State private var fadeOutTimer: Timer?
    
    private let columns = [
        GridItem(.flexible(), spacing: 15),
        GridItem(.flexible(), spacing: 15)
    ]
    
    private let cardWidth: CGFloat = UIScreen.main.bounds.width / 2 - 35
    private let cardHeight: CGFloat = 180
    
    // Use lightweight places for Created tab (no Firebase needed!)
    var lightweightCreatedPlaces: [LightweightPlace] {
        return profile.lightweightMyPlaces
    }
    
    // Get places that the current user has reviewed (similar to external user profile)
    var reviewedPlaces: [DetailPlace] {
        guard let currentUserId = profile.user?.id else { return [] }
        
        // Find all places where this user is in the placeSavers array
        let reviewedPlaceIds = profile.detailPlaceViewModel.placeSavers.compactMap { (placeId, userIds) -> String? in
            return userIds.contains(currentUserId) ? placeId : nil
        }
        
        // Get the actual DetailPlace objects for those IDs, excluding created places
        return reviewedPlaceIds.compactMap { placeId in
            guard !profile.myPlaces.contains(placeId) else { return nil } // Exclude created places
            return profile.detailPlaceViewModel.places[placeId]
        }
    }
    
    // Get places added from TikTok imports (now uses pagination)
    var tikTokPlaces: [DetailPlace] {
        return profile.getTikTokPlaces()
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    // Tab buttons
                    HStack(spacing: 30) {
                        Button(action: { 
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedTab = 0
                                displayPageIndicators()
                            }
                        }) {
                            VStack(spacing: 4) {
                                Text("Created")
                                    .font(.subheadline)
                                    .fontWeight(selectedTab == 0 ? .semibold : .regular)
                                    .foregroundColor(selectedTab == 0 ? .black : .gray)
                                    .frame(minHeight: 20)
                                
                                Rectangle()
                                    .fill(selectedTab == 0 ? Color.black : Color.clear)
                                    .frame(width: 50, height: 2)
                                    .animation(.easeInOut(duration: 0.3), value: selectedTab)
                            }
                        }
                        
                        Button(action: { 
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedTab = 1
                                displayPageIndicators()
                            }
                        }) {
                            VStack(spacing: 4) {
                                Text("Reviewed")
                                    .font(.subheadline)
                                    .fontWeight(selectedTab == 1 ? .semibold : .regular)
                                    .foregroundColor(selectedTab == 1 ? .black : .gray)
                                    .frame(minHeight: 20)
                                
                                Rectangle()
                                    .fill(selectedTab == 1 ? Color.black : Color.clear)
                                    .frame(width: 50, height: 2)
                                    .animation(.easeInOut(duration: 0.3), value: selectedTab)
                            }
                        }
                        
                        Button(action: { 
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedTab = 2
                                displayPageIndicators()
                            }
                        }) {
                            VStack(spacing: 4) {
                                Text("TikTok")
                                    .font(.subheadline)
                                    .fontWeight(selectedTab == 2 ? .semibold : .regular)
                                    .foregroundColor(selectedTab == 2 ? .black : .gray)
                                    .frame(minHeight: 20)
                                
                                Rectangle()
                                    .fill(selectedTab == 2 ? Color.black : Color.clear)
                                    .frame(width: 50, height: 2)
                                    .animation(.easeInOut(duration: 0.3), value: selectedTab)
                            }
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                    
                    // Content based on selected tab
                    if selectedTab == 0 {
                        // Created Places (lightweight - no Firebase!)
                        LightweightCreatedPlacesView(
                            lightweightPlaces: lightweightCreatedPlaces,
                            isLoading: profile.isMyPlacesLoading,
                            columns: columns,
                            cardWidth: cardWidth,
                            cardHeight: cardHeight
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                    } else if selectedTab == 1 {
                        // Reviewed Places (with pagination)
                        PaginatedReviewedPlacesView(
                            columns: columns,
                            cardWidth: cardWidth,
                            cardHeight: cardHeight,
                            colorForPlace: colorForPlace
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    } else {
                        // TikTok Places (lightweight - no Firebase!)
                        PaginatedTikTokPlacesView(
                            columns: columns,
                            cardWidth: cardWidth,
                            cardHeight: cardHeight,
                            colorForPlace: colorForPlace
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                        .onAppear {
                            // Load external places when TikTok tab appears
                            print("🎵 [MyPlacesListView] TikTok tab appeared - lightweightExternalPlaces.count: \(profile.lightweightExternalPlaces.count)")
                            if let userId = profile.user?.id {
                                print("🎵 [MyPlacesListView] User ID: \(userId), isEmpty: \(profile.lightweightExternalPlaces.isEmpty)")
                                if profile.lightweightExternalPlaces.isEmpty {
                                    print("🎵 [MyPlacesListView] Calling loadUserExternalPlaces...")
                                    Task {
                                        await profile.detailPlaceViewModel.dataManager?.loadUserExternalPlaces(userId: userId)
                                    }
                                } else {
                                    print("🎵 [MyPlacesListView] Already have \(profile.lightweightExternalPlaces.count) external places, skipping load")
                                }
                            } else {
                                print("❌ [MyPlacesListView] No user ID available")
                            }
                        }
                    }
                }
                .gesture(
                    DragGesture()
                        .onEnded { gesture in
                            let horizontalMovement = gesture.translation.width
                            let verticalMovement = abs(gesture.translation.height)
                            
                            // Only respond to primarily horizontal swipes
                            if abs(horizontalMovement) > 50 && abs(horizontalMovement) > verticalMovement {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    if horizontalMovement > 0 {
                                        // Swipe right: go to previous tab
                                        if selectedTab == 1 {
                                            selectedTab = 0 // Reviewed -> Created
                                        } else if selectedTab == 2 {
                                            selectedTab = 1 // TikTok -> Reviewed
                                        }
                                        displayPageIndicators()
                                    } else if horizontalMovement < 0 {
                                        // Swipe left: go to next tab
                                        if selectedTab == 0 {
                                            selectedTab = 1 // Created -> Reviewed
                                        } else if selectedTab == 1 {
                                            selectedTab = 2 // Reviewed -> TikTok
                                        }
                                        displayPageIndicators()
                                    }
                                }
                            }
                        }
                )
                
                // Page indicator dots at the bottom
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(selectedTab == index ? Color.gray : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .opacity(showPageIndicators ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.3), value: showPageIndicators)
                    .padding(.bottom, 10)
                }
            }
        }
        .navigationTitle("My Places")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.gray)
                }
            }
        }
        .onAppear {
            // Trigger data refresh when sheet appears
            if let userId = profile.user?.id {
                Task {
                    // Load lightweight my places (already happens on profile view, but ensure it's loaded)
                    if profile.lightweightMyPlaces.isEmpty {
                        await profile.detailPlaceViewModel.dataManager?.loadUserMyPlaces(userId: userId)
                    }
                    
                    // Load reviewed places
                    await profile.detailPlaceViewModel.dataManager?.refreshReviewedPlaces(userId: userId)
                    
                    // Preload images for reviewed (created and TikTok use AsyncImage directly!)
                    await MainActor.run {
                        profile.loadPriorityImagesForPlaces(profile.getMyReviewedPlaces(), priorityCount: 8)
                    }
                }
            }
            
            // Generate colors for reviewed places (created and TikTok use place ID hash)
            for place in reviewedPlaces {
                if placeColors[place.id] == nil {
                    placeColors[place.id] = randomColor()
                }
            }
        }
    }
    
    private func displayPageIndicators() {
        showPageIndicators = true
        fadeOutTimer?.invalidate()
        fadeOutTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                showPageIndicators = false
            }
        }
    }
    
    private func randomColor() -> Color {
        Color(
            red: Double.random(in: 0...1),
            green: Double.random(in: 0...1),
            blue: Double.random(in: 0...1)
        )
    }
    
    private func colorForPlace(_ place: DetailPlace) -> Color {
        placeColors[place.id] ?? .gray
    }
}

// MARK: - Lightweight Created Places View (No Firebase!)
struct LightweightCreatedPlacesView: View {
    let lightweightPlaces: [LightweightPlace]
    let isLoading: Bool
    let columns: [GridItem]
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var placeToDelete: String? // Store place ID
    
    var body: some View {
        if isLoading {
            VStack {
                Spacer()
                ProgressView()
                Spacer()
            }
        } else if lightweightPlaces.isEmpty {
            VStack(spacing: 16) {
                Spacer()
                Text("No Places Created Yet")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                
                Text("When you create a place, it'll appear here.")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Spacer()
            }
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 15) {
                    ForEach(Array(lightweightPlaces.enumerated()), id: \.element.id) { index, place in
                        LightweightPlaceGridCell(
                            place: place,
                            cardWidth: cardWidth,
                            cardHeight: cardHeight,
                            onLongPress: {
                                placeToDelete = place.place_id
                            }
                        )
                        .onAppear {
                            // Trigger pagination when reaching the last item
                            if index == lightweightPlaces.count - 1 && profile.hasMoreMyPlaces {
                                if let userId = profile.user?.id {
                                    Task {
                                        await dataManager.loadMoreMyPlaces(userId: userId)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Loading indicator for pagination
                    if profile.isLoadingMoreMyPlaces {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading more...")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .gridCellColumns(2)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            .alert(item: Binding(
                get: { placeToDelete.map { AlertIdentifier(id: $0) } },
                set: { placeToDelete = $0?.id }
            )) { alertId in
                Alert(
                    title: Text("Delete Place"),
                    message: Text("Are you sure you want to delete this place?"),
                    primaryButton: .destructive(Text("Delete")) {
                        // Find the DetailPlace to delete
                        if let detailPlace = profile.detailPlaceViewModel.places[alertId.id] {
                            profile.deleteMyPlace(detailPlace) { success in
                                if !success {
                                    print("❌ Failed to delete place")
                                }
                            }
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
}

// Helper struct for alert binding
struct AlertIdentifier: Identifiable {
    let id: String
}

// MARK: - Lightweight Place Grid Cell
struct LightweightPlaceGridCell: View {
    let place: LightweightPlace
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    var onLongPress: (() -> Void)? = nil
    
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
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
                // Load image directly from Supabase URL (no Firebase!)
                if let photoUrl = place.latest_review_photo, let url = URL(string: photoUrl) {
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
                }
                
                // Gradient overlay
                LinearGradient(
                    gradient: Gradient(colors: [.clear, .black.opacity(0.7)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 60)
                
                // Place name
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
        .onTapGesture {
            // Load full place details when tapped
            Task {
                await loadPlaceAndNavigate()
            }
        }
        .onLongPressGesture {
            onLongPress?()
        }
    }
    
    private func loadPlaceAndNavigate() async {
        do {
            // Fetch the full place details using PlaceService
            let fullPlace = try await PlaceService.shared.fetchPlace(withId: place.place_id)
            
            // Navigate to the place detail view
            await MainActor.run {
                selectedPlaceVM.selectedPlace = fullPlace
                selectedPlaceVM.isDetailSheetPresented = true
                presentationMode.wrappedValue.dismiss()
            }
        } catch {
            print("❌ Error loading place details: \(error)")
        }
    }
}


// MARK: - Reviewed Places View
struct PaginatedReviewedPlacesView: View {
    let columns: [GridItem]
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let colorForPlace: (DetailPlace) -> Color
    
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        if profile.isLoadingReviewedPlaces || (profile.getMyReviewedPlaces().isEmpty && !profile.isLoadingReviewedPlaces) {
            VStack {
                Spacer()
                ProgressView()
                Spacer()
            }
            .onAppear {
                profile.loadMyReviewedPlacesWithPagination()
            }
        } else if profile.getMyReviewedPlaces().isEmpty {
            VStack(spacing: 16) {
                Spacer()
                Text("No Places Reviewed Yet")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                Text("When you review a place, it'll appear here.")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Spacer()
            }
            .onAppear {
                profile.loadMyReviewedPlacesWithPagination()
            }
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 15) {
                    ForEach(Array(profile.getMyReviewedPlaces().enumerated()), id: \.element.id) { index, place in
                        PlaceGridCell(
                            place: place,
                            cardWidth: cardWidth,
                            cardHeight: cardHeight,
                            colorForPlace: colorForPlace,
                            isPriorityTile: index < 8 // First 8 tiles are priority
                        )
                        .onAppear {
                            let lastIndex = profile.getMyReviewedPlaces().count - 1
                            if index == lastIndex && profile.hasMoreReviews {
                                profile.loadMoreMyReviews()
                            }
                        }
                    }
                    if profile.isLoadingMoreReviews {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading more...")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .gridCellColumns(2)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            .onAppear {
                profile.loadMyReviewedPlacesWithPagination()
            }
        }
    }
}

// MARK: - Shared Place Grid Cell
struct PlaceGridCell: View {
    let place: DetailPlace
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let colorForPlace: (DetailPlace) -> Color
    let isPriorityTile: Bool // New parameter to indicate if this is in the first 8 tiles
    var onLongPress: (() -> Void)? = nil
    
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottom) {
                if let image = profile.detailPlaceViewModel.placeImages[place.id.uuidString], 
                   image.size.width > 0 && image.size.height > 0 {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: cardWidth, height: cardHeight)
                        .clipped()
                } else {
                    ZStack {
                        Rectangle()
                            .foregroundColor(colorForPlace(place))
                            .frame(width: cardWidth, height: cardHeight)
                        
                        // Show loading indicator if this is a priority tile and still loading
                        if isPriorityTile && profile.detailPlaceViewModel.isPlaceImageLoading(placeId: place.id.uuidString) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                    }
                    .onAppear {
                        // Load images for priority tiles immediately, or lazy load for others
                        profile.detailPlaceViewModel.fetchPlaceImage(for: place.id.uuidString)
                    }
                }
                
                // Gradient overlay
                LinearGradient(
                    gradient: Gradient(colors: [.clear, .black.opacity(0.7)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 60)
                
                // Place name and city
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                    
                    if let city = place.city {
                        Text(city)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
        .onTapGesture {
            selectedPlaceVM.selectPlaceAndFetchDetails(place)
            selectedPlaceVM.isDetailSheetPresented = true
            presentationMode.wrappedValue.dismiss()
        }
        .onLongPressGesture {
            onLongPress?()
        }
    }
}

// MARK: - Paginated TikTok Places View (Lightweight - No Firebase!)
struct PaginatedTikTokPlacesView: View {
    let columns: [GridItem]
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let colorForPlace: (DetailPlace) -> Color
    
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        if profile.isLoadingTikTokPlaces {
            VStack {
                Spacer()
                ProgressView()
                Spacer()
            }
        } else if profile.lightweightExternalPlaces.isEmpty {
            VStack(spacing: 20) {
                Image(systemName: "video.slash")
                    .font(.system(size: 50))
                    .foregroundColor(.gray.opacity(0.5))
                
                VStack(spacing: 8) {
                    Text("No TikTok Places")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("Places you add from TikTok videos will appear here")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            .padding(.top, 100)
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 15) {
                    ForEach(Array(profile.lightweightExternalPlaces.enumerated()), id: \.element.id) { index, place in
                        LightweightPlaceGridCell(
                            place: place,
                            cardWidth: cardWidth,
                            cardHeight: cardHeight
                        )
                        .onAppear {
                            // Trigger pagination when reaching the last item
                            if index == profile.lightweightExternalPlaces.count - 1 && profile.hasMoreExternalPlaces {
                                if let userId = profile.user?.id {
                                    Task {
                                        await dataManager.loadMoreExternalPlaces(userId: userId)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Loading indicator for pagination
                    if profile.isLoadingMoreExternalPlaces {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading more...")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .gridCellColumns(2)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
        }
    }
}

// MARK: - TikTokPlaceGridCell
struct TikTokPlaceGridCell: View {
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var profile: ProfileViewModel
    @Environment(\.presentationMode) var presentationMode
    
    let place: DetailPlace
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let color: Color
    let externalPlace: ExternalPlace?
    let isPriorityTile: Bool // New parameter to indicate if this is in the first 8 tiles
    
    @State private var showDeleteConfirmation = false
    
    // Get first TikTok thumbnail URL for this place
    private func getFirstTikTokThumbnail() -> String? {
        return externalPlace?.tiktokVideos.first?.thumbnailUrl
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottom) {
                // Check for TikTok thumbnails first, then review image, then colored rectangle
                if let firstTikTokThumbnail = getFirstTikTokThumbnail() {
                    AsyncImage(url: URL(string: firstTikTokThumbnail)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: cardWidth, height: cardHeight)
                            .clipped()
                    } placeholder: {
                        ZStack {
                            Rectangle()
                                .foregroundColor(color)
                                .frame(width: cardWidth, height: cardHeight)
                            
                            // Show loading indicator for priority tiles only if still loading
                            if isPriorityTile && profile.detailPlaceViewModel.isPlaceImageLoading(placeId: place.id.uuidString) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                } else if let image = profile.detailPlaceViewModel.placeImages[place.id.uuidString], 
                          image.size.width > 0 && image.size.height > 0 {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: cardWidth, height: cardHeight)
                        .clipped()
                } else {
                    ZStack {
                        Rectangle()
                            .foregroundColor(color)
                            .frame(width: cardWidth, height: cardHeight)
                        
                        // Show loading indicator for priority tiles only if still loading
                        if isPriorityTile && profile.detailPlaceViewModel.isPlaceImageLoading(placeId: place.id.uuidString) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                    }
                }
                
                // Gradient overlay for text readability
                LinearGradient(
                    gradient: Gradient(colors: [.clear, .black.opacity(0.7)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 60)
                
                // Place info - only name and city
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                    
                    if let city = place.city {
                        Text(city)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
        .onTapGesture {
            selectedPlaceVM.selectPlaceAndFetchDetails(place)
            selectedPlaceVM.isDetailSheetPresented = true
            presentationMode.wrappedValue.dismiss()
        }
        .onLongPressGesture {
            showDeleteConfirmation = true
        }
        .alert("Delete TikTok Place", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                profile.deleteTikTokPlace(place) { success in
                    if success {
                    } else {
                        print("❌ Failed to delete TikTok place: \(place.name)")
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete \"\(place.name)\"? This action cannot be undone.")
        }
    }
}

// MARK: - User Reviews View
struct UserReviewsView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        if profile.isLoadingUserReviews {
            VStack {
                Spacer()
                ProgressView()
                Text("Loading reviews...")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top, 8)
                Spacer()
            }
            .onAppear {
                Task {
                    await profile.loadUserReviews()
                }
            }
        } else if profile.userReviews.isEmpty {
            VStack(spacing: 16) {
                Spacer()
                Text("No Reviews Yet")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                Text("When you review a place, it'll appear here.")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Spacer()
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(profile.userReviews, id: \.id) { review in
                        ReviewCard(review: review)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            .onAppear {
                Task {
                    await profile.loadUserReviews()
                }
            }
        }
    }
}

// MARK: - Review Card
struct ReviewCard: View {
    let review: ReviewProtocol
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var profile: ProfileViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with place name and date
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(review.placeName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                    
                    Text(formatDate(review.timestamp))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Review type indicator
                Text(review.type.rawValue.capitalized)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(review.type == .restaurant ? Color.blue : Color.green)
                    .cornerRadius(8)
            }
            
            // Review text
            if !review.reviewText.isEmpty {
                Text(review.reviewText)
                    .font(.body)
                    .foregroundColor(.black)
                    .lineLimit(3)
            }
            
            // Restaurant-specific ratings
            if let restaurantReview = review as? RestaurantReview {
                HStack(spacing: 16) {
                    ReviewRatingView(title: "Food", rating: restaurantReview.foodRating)
                    ReviewRatingView(title: "Service", rating: restaurantReview.serviceRating)
                    ReviewRatingView(title: "Ambience", rating: restaurantReview.ambienceRating)
                }
            }
            
            // Images if available
            if !review.images.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(review.images.prefix(3), id: \.self) { imageUrl in
                            AsyncImage(url: URL(string: imageUrl)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                            }
                            .frame(width: 60, height: 60)
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .onTapGesture {
            // Navigate to place detail
            if let place = profile.detailPlaceViewModel.places[review.placeId] {
                selectedPlaceVM.selectPlaceAndFetchDetails(place)
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Review Rating View
struct ReviewRatingView: View {
    let title: String
    let rating: Double
    
    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.gray)
            
            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= Int(rating) ? "star.fill" : "star")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                }
            }
        }
    }
} 
