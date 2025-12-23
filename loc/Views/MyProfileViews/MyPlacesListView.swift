import SwiftUI
import UIKit

struct MyPlacesListView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedTab = 0
    @State private var showPageIndicators = true
    @State private var fadeOutTimer: Timer?
    
    // Use lightweight places for Created tab (no Firebase needed!)
    var lightweightCreatedPlaces: [LightweightPlace] {
        return profile.lightweightMyPlaces
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
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                    
                    // Content based on selected tab
                    if selectedTab == 0 {
                        // Created Places (lightweight - no Firebase!)
                        LightweightCreatedPlacesView(
                            lightweightPlaces: lightweightCreatedPlaces,
                            isLoading: profile.isMyPlacesLoading
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                    } else {
                        // Reviewed Places (with pagination)
                        PaginatedReviewedPlacesView()
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
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
                                    if horizontalMovement > 0 && selectedTab == 1 {
                                        // Swipe right: go to previous tab
                                        selectedTab = 0 // Reviewed -> Created
                                        displayPageIndicators()
                                    } else if horizontalMovement < 0 && selectedTab == 0 {
                                        // Swipe left: go to next tab
                                        selectedTab = 1 // Created -> Reviewed
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
                        ForEach(0..<2, id: \.self) { index in
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
}

// MARK: - Lightweight Created Places View (No Firebase!)
/// DUMB Component: Displays created places grid with pagination
/// Single Responsibility: Render place grid, delegate actions to ViewModel
struct LightweightCreatedPlacesView: View {
    let lightweightPlaces: [LightweightPlace]
    let isLoading: Bool
    
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var placeToDelete: String?
    
    // Grid layout matching ProfileView lists (consistent spacing)
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        content
            .alert(item: Binding(
                get: { placeToDelete.map { AlertIdentifier(id: $0) } },
                set: { placeToDelete = $0?.id }
            )) { alertId in
                Alert(
                    title: Text("Delete Place"),
                    message: Text("Are you sure you want to delete this place?"),
                    primaryButton: .destructive(Text("Delete")) {
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
    
    // MARK: - Content
    
    @ViewBuilder
    private var content: some View {
        if isLoading {
            initialLoadingView
        } else if lightweightPlaces.isEmpty {
            emptyStateView
        } else {
            gridView
        }
    }
    
    // MARK: - Initial Loading View
    
    private var initialLoadingView: some View {
        VStack {
            Spacer()
            ProgressView()
            Spacer()
        }
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
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
    }
    
    // MARK: - Grid View
    
    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(Array(lightweightPlaces.enumerated()), id: \.element.id) { index, place in
                    LightweightPlaceGridCell(
                        place: place,
                        onLongPress: {
                            placeToDelete = place.place_id
                        }
                    )
                    .onAppear {
                        handlePlaceAppear(index: index)
                    }
                }
                
                // Pagination loading indicator
                if profile.isLoadingMoreMyPlaces {
                    paginationLoadingView
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
    
    // MARK: - Pagination Loading View
    
    private var paginationLoadingView: some View {
        HStack {
            Spacer()
            ProgressView()
                .padding()
            Spacer()
        }
    }
    
    // MARK: - Actions
    
    private func handlePlaceAppear(index: Int) {
        // Trigger pagination when within 3 items of the end (smoother infinite scroll)
        let threshold = max(0, lightweightPlaces.count - 3)
        guard index >= threshold,
              profile.hasMoreMyPlaces,
              let userId = profile.user?.id else { return }
        
        Task {
            await dataManager.loadMoreMyPlaces(userId: userId)
        }
    }
}

// Helper struct for alert binding
struct AlertIdentifier: Identifiable {
    let id: String
}

// MARK: - Lightweight Place Grid Cell
/// Square grid cell for place display - uses aspectRatio for flexible sizing (like ProfileView lists)
/// Single Responsibility: Display place thumbnail with name overlay, handle tap/long-press
struct LightweightPlaceGridCell: View {
    let place: LightweightPlace
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
                        
                        // Place name overlay (top layer)
                        Text(place.name)
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
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
            .onLongPressGesture {
                onLongPress?()
            }
    }
    
    // MARK: - Photo Content
    @ViewBuilder
    private func photoContent(size: CGSize) -> some View {
        if let tiktokUrl = place.tiktok_url,
           let thumbnailURL = TikTokMetadataCache.shared.getCachedThumbnailUrl(for: tiktokUrl) {
            tiktokThumbnailView(thumbnailURL: thumbnailURL, tiktokUrl: tiktokUrl, size: size)
        } else if let photoUrl = place.latest_review_photo, let url = URL(string: photoUrl) {
            reviewPhotoView(url: url, size: size)
        } else {
            placeholderView
        }
    }
    
    @ViewBuilder
    private func tiktokThumbnailView(thumbnailURL: String, tiktokUrl: String, size: CGSize) -> some View {
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
                    .onAppear {
                        Task {
                            _ = await TikTokMetadataCache.shared.getMetadata(for: tiktokUrl)
                        }
                    }
            @unknown default:
                Color.clear
            }
        }
    }
    
    @ViewBuilder
    private func reviewPhotoView(url: URL, size: CGSize) -> some View {
        AsyncImage(url: url) { phase in
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
    
    private var placeholderView: some View {
        Color.clear
            .onAppear {
                // Prefetch TikTok metadata if URL exists but no cached thumbnail
                if let tiktokUrl = place.tiktok_url {
                    Task {
                        _ = await TikTokMetadataCache.shared.getMetadata(for: tiktokUrl)
                    }
                }
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
            // Fetch the full place details using PlaceService
            let fullPlace = try await PlaceService.shared.fetchPlace(withId: place.place_id)
            
            // Navigate to the place detail view
            await MainActor.run {
                // Animate map to place location and fetch fresh details from backend
                selectedPlaceVM.selectPlaceAndFetchDetails(fullPlace, shouldAnimateMap: true)
                selectedPlaceVM.isDetailSheetPresented = true
                presentationMode.wrappedValue.dismiss()
            }
        } catch {
            print("❌ Error loading place details: \(error)")
        }
    }
}


// MARK: - Reviewed Places View
/// DUMB Component: Displays reviewed places grid with pagination
/// Single Responsibility: Render reviewed places, delegate loading to ViewModel
struct PaginatedReviewedPlacesView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @Environment(\.presentationMode) var presentationMode
    
    // Grid layout matching ProfileView lists (consistent spacing)
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        content
            .onAppear {
                profile.loadMyReviewedPlacesWithPagination()
            }
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var content: some View {
        if profile.isLoadingReviewedPlaces {
            initialLoadingView
        } else if profile.lightweightReviewedPlaces.isEmpty {
            emptyStateView
        } else {
            gridView
        }
    }
    
    // MARK: - Initial Loading View
    
    private var initialLoadingView: some View {
        VStack {
            Spacer()
            ProgressView()
            Spacer()
        }
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
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
    }
    
    // MARK: - Grid View
    
    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(Array(profile.lightweightReviewedPlaces.enumerated()), id: \.element.id) { index, place in
                    LightweightPlaceGridCell(place: place)
                        .onAppear {
                            handlePlaceAppear(index: index)
                        }
                }
                
                // Pagination loading indicator
                if profile.isLoadingMoreReviews {
                    paginationLoadingView
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
    
    // MARK: - Pagination Loading View
    
    private var paginationLoadingView: some View {
        HStack {
            Spacer()
            ProgressView()
                .padding()
            Spacer()
        }
    }
    
    // MARK: - Actions
    
    private func handlePlaceAppear(index: Int) {
        // Trigger pagination when within 3 items of the end (smoother infinite scroll)
        let threshold = max(0, profile.lightweightReviewedPlaces.count - 3)
        guard index >= threshold,
              profile.hasMoreReviews,
              !profile.isLoadingMoreReviews else { return }
        
        Task {
            await profile.loadMoreMyReviews()
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
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
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

// MARK: - User Reviews View
struct UserReviewsView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        if profile.isLoadingUserPosts {
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
                    await profile.loadUserPosts()
                }
            }
        } else if profile.userPosts.isEmpty {
            VStack(spacing: 16) {
                Spacer()
                Text("No Posts Yet")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                Text("When you post about a place, it'll appear here.")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Spacer()
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(profile.userPosts, id: \.id) { post in
                        PostCard(post: post)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            .onAppear {
                Task {
                    await profile.loadUserPosts()
                }
            }
        }
    }
}

// MARK: - Post Card
struct PostCard: View {
    let post: PlacePost
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var profile: ProfileViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with place name and date
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(post.placeName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                    
                    Text(formatDate(post.timestamp))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Sentiment badge if provided
                if let wouldReturn = post.wouldReturn {
                    HStack(spacing: 4) {
                        Image(systemName: wouldReturn ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                            .font(.caption2)
                        Text(wouldReturn ? "Would go back" : "Wouldn't revisit")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(wouldReturn ? .green : .red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(wouldReturn ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            // Post text
            if !post.text.isEmpty {
                Text(post.text)
                    .font(.body)
                    .foregroundColor(.black)
                    .lineLimit(3)
            }
            
            // Images if available
            if !post.images.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(post.images.prefix(3), id: \.self) { imageUrl in
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
            if let place = profile.detailPlaceViewModel.places[post.placeId] {
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

// MARK: - Post Rating View (kept for backwards compatibility)
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
