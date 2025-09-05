import SwiftUI
import UIKit
import FirebaseFirestore

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
    
    var createdPlaces: [DetailPlace] {
        profile.myPlaces.compactMap { id in
            profile.detailPlaceViewModel.places[id]
        }
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
    
    // Get places added from TikTok imports
    var tikTokPlaces: [DetailPlace] {
        // Get all external places (TikTok imports)
        let externalPlaceIds = Array(profile.userExternalPlaces.keys)
        
        // Convert to DetailPlace objects if available
        return externalPlaceIds.compactMap { placeId in
            profile.detailPlaceViewModel.places[placeId]
        }.sorted { place1, place2 in
            // Sort by the addedAt date from external places (most recent first)
            let externalPlace1 = profile.userExternalPlaces[place1.id.uuidString]
            let externalPlace2 = profile.userExternalPlaces[place2.id.uuidString]
            
            guard let date1 = externalPlace1?.addedAt,
                  let date2 = externalPlace2?.addedAt else {
                return false
            }
            
            return date1 > date2
        }
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
                        // Created Places
                        CreatedPlacesView(
                            createdPlaces: createdPlaces,
                            isLoading: profile.isMyPlacesLoading,
                            columns: columns,
                            cardWidth: cardWidth,
                            cardHeight: cardHeight,
                            colorForPlace: colorForPlace
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
                        // TikTok Places
                        TikTokPlacesView(
                            tikTokPlaces: tikTokPlaces,
                            isLoading: false, // TikTok places are already loaded
                            columns: columns,
                            cardWidth: cardWidth,
                            cardHeight: cardHeight,
                            colorForPlace: colorForPlace
                        )
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
            // Generate colors for created, reviewed, and TikTok places
            let allPlaces = createdPlaces + reviewedPlaces + tikTokPlaces
            for place in allPlaces {
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

// MARK: - Created Places View
struct CreatedPlacesView: View {
    let createdPlaces: [DetailPlace]
    let isLoading: Bool
    let columns: [GridItem]
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let colorForPlace: (DetailPlace) -> Color
    
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var placeToDelete: DetailPlace?
    
    var body: some View {
        if isLoading {
            VStack {
                Spacer()
                ProgressView()
                Spacer()
            }
        } else if createdPlaces.isEmpty {
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
                    ForEach(createdPlaces) { place in
                        PlaceGridCell(
                            place: place,
                            cardWidth: cardWidth,
                            cardHeight: cardHeight,
                            colorForPlace: colorForPlace,
                            onLongPress: {
                                placeToDelete = place
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            .alert(item: $placeToDelete) { place in
                Alert(
                    title: Text("Delete Place"),
                    message: Text("Are you sure you want to delete this place?"),
                    primaryButton: .destructive(Text("Delete")) {
                        profile.deleteMyPlace(place) { success in
                            if !success {
                                // Handle error if needed, e.g., show an error alert
                            }
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
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
                            colorForPlace: colorForPlace
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
    var onLongPress: (() -> Void)? = nil
    
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottom) {
                if let image = profile.detailPlaceViewModel.placeImages[place.id.uuidString] {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: cardWidth, height: cardHeight)
                        .clipped()
                } else {
                    Rectangle()
                        .foregroundColor(colorForPlace(place))
                        .frame(width: cardWidth, height: cardHeight)
                }
                
                // Gradient overlay
                LinearGradient(
                    gradient: Gradient(colors: [.clear, .black.opacity(0.7)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 60)
                
                // Place name and address
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    if let type = profile.detailPlaceViewModel.placeTypes[place.id.uuidString] {
                        Text(type)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                    } else if let address = place.address {
                        Text(address)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(Color.white)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white, lineWidth: 2)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
        .onTapGesture {
            selectedPlaceVM.selectedPlace = place
            selectedPlaceVM.isDetailSheetPresented = true
            presentationMode.wrappedValue.dismiss()
        }
        .onLongPressGesture {
            onLongPress?()
        }
    }
}

// MARK: - TikTokPlacesView
struct TikTokPlacesView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @Environment(\.presentationMode) var presentationMode
    
    let tikTokPlaces: [DetailPlace]
    let isLoading: Bool
    let columns: [GridItem]
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let colorForPlace: (DetailPlace) -> Color
    
    var body: some View {
        ScrollView {
            if isLoading {
                VStack {
                    ProgressView()
                        .padding()
                    Text("Loading TikTok places...")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
            } else if tikTokPlaces.isEmpty {
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
                LazyVGrid(columns: columns, spacing: 15) {
                    ForEach(tikTokPlaces) { place in
                        TikTokPlaceGridCell(
                            place: place,
                            cardWidth: cardWidth,
                            cardHeight: cardHeight,
                            color: colorForPlace(place),
                            externalPlace: profile.userExternalPlaces[place.id.uuidString]
                        )
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
    
    var body: some View {
        ZStack {
            // Background color
            color
            
            VStack(spacing: 0) {
                // TikTok thumbnail or colored background
                ZStack {
                    color
                    
                    // Try to show TikTok thumbnail if available
                    if let thumbnailImage = profile.detailPlaceViewModel.placeImages[place.id.uuidString] {
                        Image(uiImage: thumbnailImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: cardWidth, height: cardHeight * 0.65)
                            .clipped()
                    } else {
                        // Fallback with TikTok icon
                        VStack {
                            Image(systemName: "video.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                            Text("TikTok")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                    }
                    
                    // TikTok indicator
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "video.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                                .background(
                                    Circle()
                                        .fill(Color.black.opacity(0.6))
                                        .frame(width: 20, height: 20)
                                )
                        }
                        Spacer()
                    }
                    .padding(8)
                }
                .frame(height: cardHeight * 0.65)
                
                // Place info
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    if let address = place.address {
                        Text(address)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                    
                    // Show date added from external place
                    if let externalPlace = externalPlace {
                        Text("Added \(formatDate(externalPlace.addedAt))")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
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
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white, lineWidth: 2)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
        .onTapGesture {
            selectedPlaceVM.selectedPlace = place
            selectedPlaceVM.isDetailSheetPresented = true
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
} 
