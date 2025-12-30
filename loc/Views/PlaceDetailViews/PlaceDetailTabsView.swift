//
//  PlaceDetailTabsView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/9/25.
//  Renamed from MinPlaceDetailView to better describe tabbed content view.
//

import SwiftUI
import UIKit
import CoreLocation

struct PlaceDetailTabsView: View {
    // MARK: - Primary ViewModel (One View, One ViewModel)
    @ObservedObject var viewModel: PlaceDetailTabsViewModel
    
    // MARK: - Still needed for child views (temporary during migration)
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel

    @Environment(\.isScrollingEnabled) var isScrollingEnabled
    @Binding var showNoPhoneNumberAlert: Bool
    let onPhotoTapped: ([UIImage], Int) -> Void
    
    // MARK: - Action Callbacks (passed from parent)
    let onAddToList: () -> Void
    let onAddReview: () -> Void
    
    // MARK: - View-Owned Presentation State (Enterprise Pattern)
    // Sheet presentation is a UI concern, owned by View not ViewModel
    @State private var showingSaversSheet = false
    @State private var showingHoursSheet = false
    @State private var showingNoteSheet = false
    @State private var travelSelectorState: TravelTimeSelectorState?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 5) {
                headerRow
                infoRow
                
                tabBar
                tabContent
            }
            .padding(.horizontal, 24)
        }
        .scrollDisabled(!isScrollingEnabled)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.onAppear()
        }
        .alert(isPresented: $showNoPhoneNumberAlert) {
            Alert(
                title: Text("Phone Number Not Available"),
                message: Text("No phone number is available for this place."),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert("Max Favorites Reached", isPresented: $viewModel.showMaxFavoritesAlert) {
            Button("OK", role: .cancel) {
                viewModel.dismissMaxFavoritesAlert()
            }
        } message: {
            Text("You already have 6 favorites. Remove one before adding a new one.")
        }
        // Savers Sheet - View owns presentation state (Enterprise Pattern)
        .sheet(isPresented: $showingSaversSheet) {
            PlaceSaversSheetView(
                viewModel: viewModel.placeSaversViewModel,
                placeName: viewModel.placeName
            )
            .environmentObject(profile)
            .presentationDetents(saversSheetDetents)
            .presentationDragIndicator(.visible)
        }
        // Hours Sheet - shows full opening hours when status badge is tapped
        .sheet(isPresented: $showingHoursSheet) {
            PlaceHoursSheetView(
                placeName: viewModel.placeName,
                openHours: viewModel.currentPlace?.openHours,
                currentStatus: viewModel.openStatus
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        // Note Sheet - edit private notes for this place
        .sheet(isPresented: $showingNoteSheet) {
            PlaceNoteSheetView(viewModel: viewModel.notesTabViewModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        // Travel Time Selector - capture state from child via PreferenceKey
        .onPreferenceChange(TravelTimeSelectorStateKey.self) { state in
            travelSelectorState = state
        }
        // Render expanded menu at root level for proper z-ordering
        .overlay {
            if let state = travelSelectorState, state.isExpanded {
                travelTimeSelectorOverlay(state: state)
            }
        }
    }
    
    // MARK: - Header Row (Extracted for compiler performance)
    
    private var headerRow: some View {
        HStack(alignment: .center) {
            Button(action: {
                viewModel.openGoogleMaps()
            }) {
                Text(viewModel.placeName)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Button(action: onAddToList) {
                Image(systemName: viewModel.isPlaceInList ? "bookmark.fill" : "bookmark")
                    .font(.title3)
                    .foregroundColor(.gray)
                    .frame(width: 32, height: 32)
            }
            
            Button(action: viewModel.sharePlace) {
                Image(systemName: "square.and.arrow.up")
                    .font(.title3)
                    .foregroundColor(.gray)
                    .frame(width: 32, height: 32)
            }
        }
        .padding(.bottom, 3)
    }
    
    // MARK: - Info Row (Extracted for compiler performance)
    
    @ViewBuilder
    private var infoRow: some View {
        HStack(spacing: 10) {
            if viewModel.isCustomPlace {
                CustomPlaceCreatorView(
                    viewModel: viewModel.aboutTabViewModel.customPlaceCreatorViewModel,
                    onCreatorTapped: { userId in
                        guard let currentUserId = userSession.currentUserId else { return }
                        userProfileViewModel.fetchAndSelectUser(userId: userId, currentUserId: currentUserId)
                    }
                )
            } else if let restaurantType = viewModel.restaurantType {
                Text(restaurantType)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            OpenStatusBadgeView(status: viewModel.openStatus) {
                showingHoursSheet = true
            }
            
            TravelTimeSelector(viewModel: viewModel.travelTimeViewModel)
            
            if viewModel.showSaversIndicator {
                SavedByIndicator(
                    savers: viewModel.placeSaversViewModel.saversForDisplay(limit: 3),
                    additionalCount: viewModel.placeSaversViewModel.additionalSaverCount,
                    onTap: { showingSaversSheet = true }
                )
            }
        }
        .padding(.bottom, 10)
    }
    
    // MARK: - Tab Bar (Extracted for compiler performance)
    
    private var tabBar: some View {
        HStack(spacing: 12) {
            tabButton(title: "FEED", tab: DetailTab.reviews)
            tabButton(title: "ABOUT", tab: DetailTab.about)
        }
        .padding(.bottom, 10)
    }
    
    private func tabButton(title: String, tab: DetailTab) -> some View {
        Button(action: {
            viewModel.selectTab(tab)
        }) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.black)
                .padding(.bottom, 5)
                .overlay(
                    Group {
                        if viewModel.selectedTab == tab {
                            Rectangle()
                                .fill(Color.blue)
                                .frame(height: 3)
                                .offset(y: 6)
                        }
                    },
                    alignment: .bottom
                )
        }
    }
    
    // MARK: - Tab Content (Extracted for compiler performance)
    
    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.selectedTab {
        case .about:
            AboutTabContent(
                viewModel: viewModel.aboutTabViewModel,
                onPhotoTapped: onPhotoTapped
            )
            .environmentObject(profile)
            .environmentObject(userSession)
        case .reviews:
            PlacePostsView(
                viewModel: viewModel.postsViewModel,
                onPhotoTapped: onPhotoTapped,
                onAddPost: onAddReview,
                onAddNote: { showingNoteSheet = true }
            )
            .environmentObject(selectedPlaceVM)
            .environmentObject(userProfileViewModel)
        }
    }
    
    // MARK: - Dynamic Sheet Height
    
    /// Calculates appropriate sheet detents based on number of savers
    private var saversSheetDetents: Set<PresentationDetent> {
        let count = viewModel.placeSaversViewModel.totalSaverCount
        let calculatedHeight = calculateSheetHeight(for: count)
        
        // For small lists, use exact height; for larger lists, allow expansion
        if count <= 4 {
            return [.height(calculatedHeight)]
        } else {
            return [.height(calculatedHeight), .large]
        }
    }
    
    /// Calculates sheet height based on number of savers
    private func calculateSheetHeight(for count: Int) -> CGFloat {
        let headerHeight: CGFloat = 100      // "Saved by" header + count
        let rowHeight: CGFloat = 74          // Each user row
        let bottomPadding: CGFloat = 40      // Safe area padding
        let maxHeight: CGFloat = 450         // Cap for reasonable size
        
        let calculatedHeight = headerHeight + (CGFloat(count) * rowHeight) + bottomPadding
        return min(calculatedHeight, maxHeight)
    }
    
    // MARK: - Travel Time Selector Overlay (Enterprise Pattern)
    
    /// Renders expanded menu at root level, positioned at button location
    /// Includes a dismiss background layer for tap-outside-to-close functionality
    /// This ensures proper z-ordering above all nested content
    @ViewBuilder
    private func travelTimeSelectorOverlay(state: TravelTimeSelectorState) -> some View {
        ZStack {
            // Dismiss layer - behind menu, captures taps outside
            dismissBackground
            
            // Menu positioned at button location
            GeometryReader { geo in
                let localFrame = CGRect(
                    x: state.frame.minX - geo.frame(in: .global).minX,
                    y: state.frame.maxY - geo.frame(in: .global).minY + 8,
                    width: state.frame.width,
                    height: 0
                )
                
                TravelTimeSelectorExpandedMenu(
                    viewModel: viewModel.travelTimeViewModel,
                    selectedIndex: state.selectedIndex,
                    onSelect: { transportType in
                        withAnimation(.easeIn(duration: 0.2)) {
                            viewModel.travelTimeViewModel.switchTransportType(to: transportType)
                            viewModel.travelTimeViewModel.saveDefaultTransportType(transportType)
                            viewModel.travelTimeViewModel.collapseMenu()
                        }
                    },
                    onDismiss: {
                        withAnimation(.easeIn(duration: 0.2)) {
                            viewModel.travelTimeViewModel.collapseMenu()
                        }
                    }
                )
                .position(x: localFrame.minX + 90, y: localFrame.minY + 100)
                .transition(.scale(scale: 0.8, anchor: .top).combined(with: .opacity))
                .animation(.easeOut(duration: 0.2), value: state.isExpanded)
            }
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Menu Dismiss Background
    
    /// Full-screen transparent layer that dismisses the transport menu when tapped
    /// Uses minimal opacity to remain invisible while capturing taps outside the menu
    private var dismissBackground: some View {
        Color.black.opacity(0.001)
            .ignoresSafeArea()
            .onTapGesture {
                withAnimation(.easeIn(duration: 0.2)) {
                    viewModel.travelTimeViewModel.collapseMenu()
                }
            }
    }
}

// MARK: - Saved By Indicator (Dumb Display Component - No ViewModel)

private struct SavedByIndicator: View {
    // MARK: - Pure Data Parameters (No ViewModel!)
    let savers: [ProfileData]
    let additionalCount: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                // Overlapping profile circles in their own container
                HStack(spacing: -8) {
                    ForEach(savers, id: \.id) { saver in
                        if let photoURL = saver.profilePhotoURL {
                            AsyncImage(url: photoURL) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 24, height: 24)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle().stroke(Color.white, lineWidth: 2)
                                        )
                                case .failure, .empty:
                                    placeholderCircle(for: saver)
                                @unknown default:
                                    placeholderCircle(for: saver)
                                }
                            }
                            .frame(width: 24, height: 24)
                        } else {
                            placeholderCircle(for: saver)
                        }
                    }
                }
                
                // +X indicator outside the overlapping circles
                if additionalCount > 0 {
                    Text("+\(additionalCount)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    private func placeholderCircle(for saver: ProfileData) -> some View {
        Circle()
            .fill(Color(.systemGray4))
            .frame(width: 24, height: 24)
            .overlay(
                Text(saver.fullName.prefix(1))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
            )
            .overlay(
                Circle().stroke(Color.white, lineWidth: 2)
            )
    }
}

// MARK: - Preview (Dramatically Simplified!)
#Preview {
    struct PreviewWrapper: View {
        @State private var showNoPhoneNumberAlert = false
        
        var body: some View {
            let services = ServiceContainer.shared
            let locationManager = LocationManager()
            
            // Create minimal dependencies for preview
            let detailPlaceVM = DetailPlaceViewModel(
                placeService: services.placeService,
                userService: services.userService
            )
            
            let selectedPlaceVM = SelectedPlaceViewModel(
                locationManager: locationManager,
                postService: services.postService,
                placeService: services.placeService,
                userService: services.userService,
                imageService: services.imageService,
                detailPlaceViewModel: detailPlaceVM
            )
            
            let userSession = UserSession(
                userService: services.userService,
                locationManager: locationManager,
                detailPlaceVM: detailPlaceVM
            )
            
            let profileVM = ProfileViewModel(
                userSession: userSession,
                userService: services.userService,
                detailPlaceViewModel: detailPlaceVM,
                imageService: services.imageService,
                placeService: services.placeService,
                postService: services.postService,
                locationManager: locationManager,
                deepLinkManager: services.deepLinkManager,
                deepLinkViewModel: nil
            )
            
            let dataManager = DataManager(
                userService: services.userService,
                placeService: services.placeService,
                postService: services.postService,
                userSession: userSession,
                locationManager: locationManager,
                profileViewModel: profileVM,
                detailPlaceViewModel: detailPlaceVM
            )
            
            let userProfileVM = UserProfileViewModel(
                dataManager: dataManager,
                detailPlaceViewModel: detailPlaceVM,
                placeService: services.placeService,
                userService: services.userService,
                postService: services.postService,
                userSession: userSession
            )
            
            // Create a mock place and set it
            let mockPlace: DetailPlace = {
                var place = DetailPlace()
                place.name = "Sample Restaurant"
                place.address = "123 Main St"
                place.city = "San Francisco"
                place.coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
                place.categories = ["restaurant", "italian"]
                place.rating = 4.5
                place.userRatingsTotal = 234
                return place
            }()
            
            selectedPlaceVM.selectedPlace = mockPlace
            
            // Create the new ViewModel (Our Single Source of Truth!)
            let tabsViewModel = PlaceDetailTabsViewModel(
                placeService: services.placeService,
                postService: services.postService,
                userService: services.userService,
                notificationManager: NotificationManager.shared,
                placeShareService: services.placeShareService,
                selectedPlaceVM: selectedPlaceVM,
                profileVM: profileVM,
                userSession: userSession,
                detailPlaceViewModel: detailPlaceVM
            )
            
            return PlaceDetailTabsView(
                viewModel: tabsViewModel,
                showNoPhoneNumberAlert: $showNoPhoneNumberAlert,
                onPhotoTapped: { photos, index in
                    print("Tapped photo at index: \(index)")
                },
                onAddToList: { print("Add to list tapped") },
                onAddReview: { print("Add review tapped") }
            )
            .environmentObject(profileVM)
            .environmentObject(selectedPlaceVM)
            .environmentObject(userProfileVM)
            .environmentObject(userSession)
            .environmentObject(detailPlaceVM)
            .environment(\.isScrollingEnabled, true)
            .padding()
        }
    }
    
    return PreviewWrapper()
}
