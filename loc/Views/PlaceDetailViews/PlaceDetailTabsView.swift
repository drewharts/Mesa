//
//  PlaceDetailTabsView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/9/25.
//  Renamed from MinPlaceDetailView. Despite the name there are no tabs anymore: it is one scrolling sheet
//  (header, media strip, about content, reviews, help-improve row).
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
    @EnvironmentObject var userProfileNavigationVM: UserProfileNavigationViewModel
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel

    @Binding var showNoPhoneNumberAlert: Bool
    let onPhotoTapped: ([String], Int) -> Void  // URLs instead of UIImages
    
    // MARK: - Action Callbacks (passed from parent)
    let onAddToList: () -> Void
    let onAddReview: () -> Void
    var onCreatePlace: (() -> Void)?

    /// Callback when user changes a video's place association - parent should navigate to new place
    var onPlaceChanged: ((DetailPlace) -> Void)?
    
    // MARK: - Story Card ViewModel
    @StateObject private var placeStoryCardVM = PlaceStoryCardViewModel()

    // MARK: - View-Owned Presentation State (Enterprise Pattern)
    // Sheet presentation is a UI concern, owned by View not ViewModel
    @State private var showingSaversSheet = false
    @State private var showingHoursSheet = false
    @State private var showingCategoryCorrectionSheet = false
    @State private var showingNoteSheet = false
    @State private var showPlacePhotoSelector = false
    @State private var travelSelectorState: TravelTimeSelectorState?
    /// Owns the "Added to New York City" banner and the city-list save behind the bookmark.
    @StateObject private var saveBanner = CitySaveBannerViewModel()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                topBlock
                mediaStrip
                mainContent
                    .padding(.horizontal, 16)
                    .transaction { $0.animation = nil }
            }
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
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
        // Category Correction Sheet - correct the place's category
        .sheet(isPresented: $showingCategoryCorrectionSheet) {
            CategoryCorrectionSheet(
                placeId: viewModel.currentPlace?.id.uuidString ?? "",
                currentCategory: viewModel.restaurantType,
                hasCorrectionOverride: viewModel.currentPlace?.userCorrectedCategory != nil,
                onCorrectionSaved: { category in
                    viewModel.applyCategoryCorrection(category)
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        // Note Sheet - edit private notes for this place
        .sheet(isPresented: $showingNoteSheet) {
            PlaceNoteSheetView(viewModel: viewModel.notesTabViewModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        // Place Story Card Photo Selector Sheet
        .sheet(isPresented: $showPlacePhotoSelector) {
            PlaceStoryPhotoSelectorView(
                viewModel: placeStoryCardVM,
                onShareInstagram: {
                    guard let place = viewModel.currentPlace else { return }
                    Task { await placeStoryCardVM.shareToInstagram(place: place) }
                },
                onShareGeneral: {
                    guard let place = viewModel.currentPlace else { return }
                    Task { await placeStoryCardVM.shareGeneral(place: place) }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationContentInteraction(.resizes)
            .presentationDragIndicator(.visible)
        }
        // Link Copied Instruction Alert (shown after Instagram share)
        .alert(
            "Link Copied",
            isPresented: $placeStoryCardVM.showLinkCopiedInstruction
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Add a link sticker in Instagram and paste the copied link so viewers can find this place on Mesa.")
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
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }
            .buttonStyle(.plain)

            Spacer()

            if viewModel.isDroppedPin {
                Button(action: { onCreatePlace?() }) {
                    Text("Create Place")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(20)
                }
                .accessibilityIdentifier("place.detail.createPlace")
            } else {
                Button(action: handleBookmarkTap) {
                    Image(systemName: viewModel.isPlaceInList ? "bookmark.fill" : "bookmark")
                        .font(.title3)
                        .foregroundColor(.gray)
                        .frame(width: 32, height: 32)
                }
                .accessibilityIdentifier("place.detail.save")

                shareButton
            }
        }
    }

    // MARK: - Sections

    /// Title row, save banner and meta/status block.
    private var topBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            headerRow
            if let message = saveBanner.message {
                quickSaveBannerView(message)
            }
            infoRow
        }
        .padding(.horizontal, 16)
    }

    /// Edge-to-edge photo + video strip right under the title block.
    private var mediaStrip: some View {
        PlaceMediaStripView(
            viewModel: viewModel.aboutTabViewModel.mediaStripViewModel,
            placeId: viewModel.currentPlace?.id.uuidString ?? "",
            onPhotoTapped: onPhotoTapped
        )
        .environmentObject(userSession)
    }

    /// About content, reviews and the compact help-improve row, with no empty gaps between them.
    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            AboutTabContent(
                viewModel: viewModel.aboutTabViewModel,
                onAddPost: onAddReview,
                onEditNote: { showingNoteSheet = true },
                isRefreshing: viewModel.isRefreshing,
                onRefresh: viewModel.manualRefresh
            )
            PlacePostsView(viewModel: viewModel.postsViewModel)
                .environmentObject(selectedPlaceVM)
                .environmentObject(userProfileNavigationVM)
            ExternalVideosSection(
                viewModel: viewModel.aboutTabViewModel.externalVideosViewModel,
                selectedPlace: viewModel.currentPlace,
                onPlaceChanged: onPlaceChanged
            )
            .environmentObject(profile)
        }
    }

    // MARK: - One-tap save (city list)

    /// The bookmark saves an unsaved place into its city list in one tap; a saved place (or a dropped
    /// pin) opens the usual list picker.
    private func handleBookmarkTap() {
        guard !viewModel.isPlaceInList, !viewModel.isDroppedPin, let place = viewModel.currentPlace else {
            onAddToList()
            return
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        Task { @MainActor in
            let saved = await saveBanner.save([place], profile: profile, userSession: userSession)
            if saved { viewModel.isPlaceInList = true }
        }
    }

    /// Low-key confirmation under the title with the one secondary action: change the list.
    private func quickSaveBannerView(_ message: String) -> some View {
        SavedBannerView(message: message, isError: saveBanner.isError) {
            saveBanner.dismiss()
            onAddToList()
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
        .onChange(of: viewModel.currentPlace?.id) { _, _ in saveBanner.dismiss() }
    }

    // MARK: - Share Button (Conditional: Menu for custom places, simple button otherwise)

    @ViewBuilder
    private var shareButton: some View {
        if viewModel.isCustomPlace {
            customPlaceShareMenu
        } else {
            Button(action: viewModel.sharePlace) {
                shareIcon
            }
            .accessibilityIdentifier("place.detail.share")
        }
    }

    /// Menu with "Share Link" and "Create Story Card" options for custom places.
    private var customPlaceShareMenu: some View {
        Menu {
            Button {
                viewModel.sharePlace()
            } label: {
                Label("Share Link", systemImage: "link")
            }

            Button {
                guard let place = viewModel.currentPlace else { return }
                let posts = viewModel.currentPlacePosts
                Task {
                    await placeStoryCardVM.preparePhotoOptions(place: place, posts: posts)
                    showPlacePhotoSelector = true
                }
            } label: {
                Label("Create Story Card", systemImage: "rectangle.portrait.on.rectangle.portrait")
            }
        } label: {
            shareIcon
        }
    }

    /// Shared share icon used by both simple button and menu.
    private var shareIcon: some View {
        Image(systemName: "square.and.arrow.up")
            .font(.title3)
            .foregroundColor(.gray)
            .frame(width: 32, height: 32)
    }

    // MARK: - Info Row (Extracted for compiler performance)
    
    /// Meta (category, travel time, savers) with the open/closed pill inline when it fits, wrapped below otherwise.
    private var infoRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                metaItems
                openStatusBadge
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) { metaItems }
                openStatusBadge
            }
        }
    }

    @ViewBuilder
    private var openStatusBadge: some View {
        if viewModel.openStatus.shouldDisplay {
            OpenStatusBadgeView(
                status: viewModel.openStatus,
                onTap: { showingHoursSheet = true },
                detailText: viewModel.openStatusChangeText
            )
        }
    }

    /// Category (or custom place creator), travel-time selector and savers indicator.
    @ViewBuilder
    private var metaItems: some View {
        if viewModel.isCustomPlace {
            CustomPlaceCreatorView(
                viewModel: viewModel.aboutTabViewModel.customPlaceCreatorViewModel,
                onCreatorTapped: { userId in
                    guard let currentUserId = userSession.currentUserId else { return }
                    userProfileNavigationVM.fetchAndSelectUser(userId: userId, currentUserId: currentUserId)
                }
            )
            .layoutPriority(-1)
        } else if let restaurantType = viewModel.restaurantType {
            Button {
                showingCategoryCorrectionSheet = true
            } label: {
                Text(restaurantType)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .layoutPriority(-1)
        }

        TravelTimeSelector(viewModel: viewModel.travelTimeViewModel)
            .fixedSize()

        if viewModel.showSaversIndicator {
            SavedByIndicator(
                savers: viewModel.placeSaversViewModel.saversForDisplay(limit: 3),
                additionalCount: viewModel.placeSaversViewModel.additionalSaverCount,
                onTap: { showingSaversSheet = true }
            )
            .fixedSize()
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
                // Profile circles for savers (followed first, then unfollowed)
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

                // +X indicator for additional savers beyond the circles
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
            
            let userProfileNavigationVM = UserProfileNavigationViewModel(
                userService: services.userService,
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
                userSession: userSession,
                profileVM: profileVM,
                detailPlaceViewModel: detailPlaceVM,
                selectedPlaceVM: selectedPlaceVM
            )

            // Set initial data
            tabsViewModel.setPlace(mockPlace)
            tabsViewModel.setPosts([], rating: 0)
            tabsViewModel.setExternalVideos(placeVideos: [], userVideos: [])
            
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
            .environmentObject(userProfileNavigationVM)
            .environmentObject(userSession)
            .environmentObject(detailPlaceVM)
            .padding()
        }
    }
    
    return PreviewWrapper()
}
