//
//  MinPlaceDetailView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/9/25.
//

import SwiftUI
import FirebaseFirestore
import UIKit

struct MinPlaceDetailView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @ObservedObject var viewModel: PlaceDetailViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    @EnvironmentObject var notificationManager: NotificationManager
    @Environment(\.isScrollingEnabled) var isScrollingEnabled // Access scroll state

    @Binding var showNoPhoneNumberAlert: Bool
    let onPhotoTapped: ([UIImage], Int) -> Void
    
    @State private var selectedTab: DetailTab = .reviews
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 5) {
                // MARK: - Top Row: Title + Icons
                HStack(alignment: .center) {
                    Text(selectedPlaceVM.selectedPlace?.name ?? "Unnamed Place")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                    
                    Spacer()
                }
                .padding(.bottom, 3)
                
                // MARK: - Row: Type / Google Maps / Drive Time
                HStack(spacing: 10) {
                    Text(viewModel.getRestaurantType(for: selectedPlaceVM.selectedPlace!) ?? "Restaurant")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Button(action: {
                        if let place = selectedPlaceVM.selectedPlace {
                            let name = place.name ?? "Unknown Place"
                            // If we have an address, include it for more accurate search
                            if let address = place.address {
                                viewModel.openGoogleMapsWithPlace(query: "\(name), \(address)")
                            } else if let latitude = place.coordinate?.latitude,
                                      let longitude = place.coordinate?.longitude {
                                // If no address, use name with coordinates
                                viewModel.openGoogleMapsWithPlace(query: "\(name) @\(latitude),\(longitude)")
                            } else {
                                // Fallback to just using the name
                                viewModel.openGoogleMapsWithPlace(query: name)
                            }
                        }
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
                    
                    HStack(spacing: 4) {
                        Image(systemName: "car.fill")
                            .foregroundColor(.gray)
                        
                        Text(viewModel.travelTime)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .onTapGesture {
                        if let place = selectedPlaceVM.selectedPlace,
                           let currentLocation = locationManager.currentLocation {
                            viewModel.openNavigation(for: place, currentLocation: currentLocation.coordinate)
                        }
                    }
                }
                .padding(.bottom, 10)
                
                // MARK: - Row: REVIEWS / Rating / ABOUT / Avatars
                HStack(spacing: 12) {
                    Button(action: {
                        selectedTab = .reviews
                    }) {
                        Text("REVIEWS")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                            .padding(.bottom, 5)
                            .overlay(
                                Group {
                                    if selectedTab == .reviews {
                                        Rectangle()
                                            .fill(Color.blue)
                                            .frame(height: 3)
                                            .offset(y: 6)
                                    }
                                },
                                alignment: .bottom
                            )
                    }
                    
                    if !selectedPlaceVM.reviews.isEmpty && (selectedPlaceVM.placeRating ?? 0.0) > 0 {
                        Text(String(format: "%.1f", selectedPlaceVM.placeRating ?? 0.0))
                            .font(.caption)
                            .foregroundColor(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color.yellow)
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        selectedTab = .about
                    }) {
                        Text("ABOUT")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                            .padding(.bottom, 5)
                            .overlay(
                                Group {
                                    if selectedTab == .about {
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
                switch selectedTab {
                case .about:
                    Text(selectedPlaceVM.selectedPlace?.description ?? "No description available")
                        .font(.footnote)
                        .foregroundColor(.black)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Divider()
                        .padding(.top, 15)
                        .padding(.bottom, 15)
                    
                    MaxPlaceDetailView(
                        viewModel: viewModel,
                        onPhotoTapped: onPhotoTapped,
                        showNoPhoneNumberAlert: $showNoPhoneNumberAlert
                    )
                case .reviews:
                    PlaceReviewsView(onPhotoTapped: onPhotoTapped)
                        .environmentObject(userProfileViewModel)
                }
            }
            .padding(.horizontal, 30)
        }
        .scrollDisabled(!isScrollingEnabled) // Disable scrolling based on sheet height
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(notificationManager.$highlightedReviewId) { reviewId in
            if reviewId != nil {
                // Switch to reviews tab when there's a highlighted review
                selectedTab = .reviews
            }
        }
        .alert(isPresented: $showNoPhoneNumberAlert) {
            Alert(
                title: Text("Phone Number Not Available"),
                message: Text("No phone number is available for this place."),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert("Max Favorites Reached", isPresented: $profile.showMaxFavoritesAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You already have 4 favorites. Remove one before adding a new one.")
        }
    }
}

// MARK: - Sub-Types
enum DetailTab {
    case about
    case reviews
}