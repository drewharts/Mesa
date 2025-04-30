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
    @Environment(\.isScrollingEnabled) var isScrollingEnabled // Access scroll state

    @Binding var showNoPhoneNumberAlert: Bool
    @Binding var selectedImage: UIImage?
    
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
                        Image(systemName: "map.fill")
                            .font(.subheadline)
                            .foregroundColor(Color.green.opacity(0.8))
                    }
                    .padding(.leading, 5)
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        NavigationLink(destination: CreatePlaceReviewView(isPresented: .constant(false), place: selectedPlaceVM.selectedPlace!, userId: profile.user.id!, profilePhotoUrl: profile.user?.profilePhotoURL.absoluteString ?? "", userFirstName: profile.user?.firstName, userLastName: profile.user?.lastName)) {
                            Image(systemName: "plus")
                                .font(.title3)
                        }
                        
                        Button(action: {
                            viewModel.showListSelection = true
                        }) {
                            Image(systemName: profile.isPlaceInAnyList(placeId: selectedPlaceVM.selectedPlace?.id.uuidString ?? "") ? "bookmark.fill" : "bookmark")
                                .font(.title3)
                        }
                    }
                }
                .padding(.bottom, 3)
                
                // MARK: - Row: Type / Status / Drive Time
                HStack(spacing: 10) {
                    Text(viewModel.getRestaurantType(for: selectedPlaceVM.selectedPlace!) ?? "Restaurant")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 8))
                            .foregroundColor(selectedPlaceVM.isRestaurantOpen ? .green : .red)
                        
                        Text(selectedPlaceVM.isRestaurantOpen ? "Open" : "Closed")
                            .font(.subheadline)
                            .foregroundColor(selectedPlaceVM.isRestaurantOpen ? .green : .red)
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
                        selectedImage: $selectedImage,
                        showNoPhoneNumberAlert: $showNoPhoneNumberAlert
                    )
                case .reviews:
                    PlaceReviewsView(selectedImage: $selectedImage)
                        .environmentObject(userProfileViewModel)
                }
            }
            .padding(.horizontal, 30)
        }
        .scrollDisabled(!isScrollingEnabled) // Disable scrolling based on sheet height
        .navigationBarTitleDisplayMode(.inline)
        .alert(isPresented: $showNoPhoneNumberAlert) {
            Alert(
                title: Text("Phone Number Not Available"),
                message: Text("No phone number is available for this place."),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

// MARK: - Sub-Types
enum DetailTab {
    case about
    case reviews
}

// MARK: - Profile Circles View
struct ProfileCirclesView: View {
    @EnvironmentObject var profile: ProfileViewModel
    let placeId: String?
    
    var body: some View {
        Group {
            if let placeId = placeId {
                // Get unique users who saved this place, excluding current user
                let uniqueUsers = profile.getUniquePlaceSaversExcludingCurrentUser(forPlaceId: placeId)
                
                // Only show the profile circles if we actually have other unique users
                if !uniqueUsers.isEmpty {
                    HStack(spacing: -10) {
                        // Get profile images for this place (we'll still use getFirstThreeProfileImages since
                        // it pulls from DetailPlaceViewModel.placeSavers which has the correct filtering)
                        let (image1, image2, image3) = getProfileImagesForDisplayedUsers(users: uniqueUsers, placeId: placeId)
                        
                        // First profile image
                        if let image1 = image1 {
                            profileCircleImage(image: image1)
                        }
                        
                        // Second profile image
                        if let image2 = image2 {
                            profileCircleImage(image: image2)
                        }
                        
                        // Third or +more indicator
                        if let image3 = image3 {
                            profileCircleImage(image: image3)
                        } else if uniqueUsers.count > 2 {
                            // Show +X if there are more than shown
                            plusCircle(count: uniqueUsers.count - 2)
                        }
                    }
                }
            } else {
                // If no users have saved this place, display nothing
                EmptyView()
            }
        }
    }
    
    // Helper method to get profile images for displayed users
    private func getProfileImagesForDisplayedUsers(users: [User], placeId: String) -> (UIImage?, UIImage?, UIImage?) {
        guard !users.isEmpty else { return (nil, nil, nil) }
        
        let firstThreeUsers = users.prefix(3)
        let images = firstThreeUsers.map { user -> UIImage? in
            profile.profilePhoto(forUserId: user.id)
        }
        
        let paddedImages = (images + [nil, nil, nil]).prefix(3)
        return (paddedImages[0], paddedImages[1], paddedImages[2])
    }
    
    // Helper view for profile image circle
    private func profileCircleImage(image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: 30, height: 30)
            .clipShape(Circle())
            .overlay(
                Circle().stroke(Color.white, lineWidth: 2)
            )
    }
    
    // Helper view for the +X circle
    private func plusCircle(count: Int) -> some View {
        ZStack {
            Circle()
                .fill(Color.gray)
                .frame(width: 30, height: 30)
                .overlay(
                    Circle().stroke(Color.white, lineWidth: 2)
                )
            
            Text("+\(count)")
                .font(.caption)
                .foregroundColor(.white)
        }
    }
}
