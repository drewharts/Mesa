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
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    // Tab buttons
                    HStack(spacing: 40) {
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
                    } else {
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
                                        // Swipe right: go to Created
                                        selectedTab = 0
                                        displayPageIndicators()
                                    } else if horizontalMovement < 0 && selectedTab == 0 {
                                        // Swipe left: go to Reviewed
                                        selectedTab = 1
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
            // Generate colors for both created and reviewed places
            let allPlaces = createdPlaces + reviewedPlaces
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
                            colorForPlace: colorForPlace
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
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
    
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        Button(action: {
            selectedPlaceVM.selectedPlace = place
            selectedPlaceVM.isDetailSheetPresented = true
            presentationMode.wrappedValue.dismiss()
        }) {
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
        }
    }
} 
