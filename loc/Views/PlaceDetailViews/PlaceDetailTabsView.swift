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
    
    // MARK: - View-Owned Presentation State (Enterprise Pattern)
    // Sheet presentation is a UI concern, owned by View not ViewModel
    @State private var showingSaversSheet = false
    @State private var travelSelectorState: TravelTimeSelectorState?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 5) {
                // MARK: - Top Row: Title + Icons
                HStack(alignment: .center) {
                    Text(viewModel.placeName)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                    
                    Spacer()
                }
                .padding(.bottom, 3)
                
                // MARK: - Row: Type / Created By / Google Maps / Drive Time / Saved By
                HStack(spacing: 10) {
                    // Show "Created by [photo]" for custom places, otherwise show type
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
                    
                    Button(action: {
                        viewModel.openGoogleMaps()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "map.fill")
                                .font(.subheadline)
                                .foregroundColor(Color.green.opacity(0.8))
                            
                            Text("Maps")
                                .font(.subheadline)
                                .foregroundColor(Color.green.opacity(0.8))
                        }
                    }
                    
                    TravelTimeSelector(viewModel: viewModel.travelTimeViewModel)
                    
                    // Saved By indicator - tappable to show sheet
                    if viewModel.showSaversIndicator {
                        SavedByIndicator(
                            savers: viewModel.placeSaversViewModel.saversForDisplay(limit: 3),
                            additionalCount: viewModel.placeSaversViewModel.additionalSaverCount,
                            onTap: { showingSaversSheet = true }
                        )
                    }
                }
                .padding(.bottom, 10)
                
                // MARK: - Row: REVIEWS / Rating / ABOUT
                HStack(spacing: 12) {
                    Button(action: {
                        viewModel.selectTab(.reviews)
                    }) {
                        Text("REVIEWS")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                            .padding(.bottom, 5)
                            .overlay(
                                Group {
                                    if viewModel.selectedTab == .reviews {
                                        Rectangle()
                                            .fill(Color.blue)
                                            .frame(height: 3)
                                            .offset(y: 6)
                                    }
                                },
                                alignment: .bottom
                            )
                    }
                    
                    Button(action: {
                        viewModel.selectTab(.notes)
                    }) {
                        Text("NOTES")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                            .padding(.bottom, 5)
                            .overlay(
                                Group {
                                    if viewModel.selectedTab == .notes {
                                        Rectangle()
                                            .fill(Color.blue)
                                            .frame(height: 3)
                                            .offset(y: 6)
                                    }
                                },
                                alignment: .bottom
                            )
                    }
                    
                    if viewModel.hasReviews && viewModel.placeRating > 0 {
                        Text(String(format: "%.1f", viewModel.placeRating))
                            .font(.caption)
                            .foregroundColor(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color.yellow)
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        viewModel.selectTab(.about)
                    }) {
                        Text("ABOUT")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                            .padding(.bottom, 5)
                            .overlay(
                                Group {
                                    if viewModel.selectedTab == .about {
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
                .padding(.bottom, 10)
                
                // MARK: - Tab-Specific Content
                switch viewModel.selectedTab {
                case .about:
                    AboutTabContent(
                        viewModel: viewModel.aboutTabViewModel,
                        onPhotoTapped: onPhotoTapped
                    )
                    .environmentObject(profile)
                    .environmentObject(userSession)
                case .reviews:
                    PlaceReviewsView(
                        viewModel: viewModel.reviewsViewModel,
                        onPhotoTapped: onPhotoTapped
                    )
                    .environmentObject(selectedPlaceVM)
                        .environmentObject(userProfileViewModel)
                case .notes:
                    NotesTabContent(viewModel: viewModel.notesTabViewModel)
                }
            }
            .padding(.horizontal, 30)
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
            Button("OK", role: .cancel) { }
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
    /// This ensures proper z-ordering above all nested content
    @ViewBuilder
    private func travelTimeSelectorOverlay(state: TravelTimeSelectorState) -> some View {
        GeometryReader { geo in
            // Convert global frame to local coordinate space
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
                    viewModel.travelTimeViewModel.switchTransportType(to: transportType)
                    viewModel.travelTimeViewModel.saveDefaultTransportType(transportType)
                },
                onDismiss: { }
            )
            .position(x: localFrame.minX + 90, y: localFrame.minY + 100)
            .transition(.scale(scale: 0.8, anchor: .top).combined(with: .opacity))
            .animation(.easeOut(duration: 0.2), value: state.isExpanded)
        }
        .ignoresSafeArea()
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
                reviewService: services.reviewService,
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
                reviewService: services.reviewService,
                locationManager: locationManager,
                deepLinkManager: services.deepLinkManager,
                deepLinkViewModel: nil
            )
            
            let dataManager = DataManager(
                userService: services.userService,
                placeService: services.placeService,
                reviewService: services.reviewService,
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
                reviewService: services.reviewService
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
                reviewService: services.reviewService,
                userService: services.userService,
                notificationManager: NotificationManager.shared,
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
                }
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
