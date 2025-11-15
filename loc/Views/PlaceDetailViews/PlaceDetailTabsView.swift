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
    
    @Environment(\.isScrollingEnabled) var isScrollingEnabled
    @Binding var showNoPhoneNumberAlert: Bool
    let onPhotoTapped: ([UIImage], Int) -> Void
    
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
                
                // MARK: - Row: Type / Google Maps / Drive Time
                HStack(spacing: 10) {
                    if let restaurantType = viewModel.restaurantType {
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
                }
                .padding(.bottom, 10)
                
                // MARK: - Row: REVIEWS / Rating / ABOUT / Avatars
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
                    
                    ProfileCirclesView(placeId: selectedPlaceVM.selectedPlace?.id.uuidString)
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
                userSession: userSession
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
            .environment(\.isScrollingEnabled, true)
            .padding()
        }
    }
    
    return PreviewWrapper()
}
