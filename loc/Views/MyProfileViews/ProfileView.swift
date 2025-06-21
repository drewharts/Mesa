//  ProfileView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/9/24.
//

import SwiftUI
import PhotosUI
import FirebaseFirestore

struct ProfileView: View {
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var placeVM: DetailPlaceViewModel
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    @StateObject private var photoImportVM = PhotoImportViewModel()
    
    @State private var showCreateReview = false
    @State private var selectedReviewType: CreatePlaceReviewView.ReviewType = .restaurant
    


    init() {
        // Configure navigation bar appearance to remove the bottom border
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground() // Use opaque background
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Profile Picture
                ProfilePictureView()

                // Name
                let firstName = profile.user?.firstName ?? ""
                let lastName = profile.user?.lastName ?? ""
                Text("\(firstName) \(lastName)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                
                // Follow Counts
                ProfileFollowCountsView()

                Divider()
                    .padding(.top, 15)
                    .padding(.horizontal, 20)
                
                // Favorites & Lists
                ProfileFavoriteListView()
                ProfileViewListsView()

                // No Location Data Error
                if photoImportVM.noLocationDataError {
                    VStack(spacing: 12) {
                        Text("📍 NO LOCATION DATA")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        VStack(spacing: 8) {
                            Text("None of the selected photos contain GPS coordinates")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            
                            Text("To create a review, please select photos taken with location services enabled")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                        }
                        
                        Button("TRY AGAIN") {
                            photoImportVM.clearSelection()
                        }
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.white)
                        .cornerRadius(8)
                    }
                    .padding(20)
                    .background(Color.red)
                    .cornerRadius(15)
                    .padding(.horizontal, 20)
                    .shadow(radius: 10)
                }
                
                // Photo Processing Display
                else if let coordinates = photoImportVM.detectedCoordinates {
                    VStack(spacing: 12) {
                        Text("📍 PHOTO COORDINATES")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        VStack(spacing: 8) {
                            Text("Latitude: \(coordinates.latitude, specifier: "%.6f")")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            Text("Longitude: \(coordinates.longitude, specifier: "%.6f")")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        
                        // Loading nearby places indicator
                        if photoImportVM.isLoadingNearbyPlaces {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Finding nearby places...")
                                    .font(.subheadline)
                            }
                            .foregroundColor(.white)
                        }
                        
                        // Selected place display
                        if let selectedPlace = photoImportVM.selectedPlace {
                            VStack(spacing: 4) {
                                Text("✅ Selected Place:")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                Text(selectedPlace.properties.name)
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                        }
                        
                        Button("CLEAR ALL") {
                            photoImportVM.clearSelection()
                        }
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.white)
                        .cornerRadius(8)
                    }
                    .padding(20)
                    .background(Color.blue)
                    .cornerRadius(15)
                    .padding(.horizontal, 20)
                    .shadow(radius: 10)
                }

                // Logout Button
                Button(action: {
                    userSession.logout()
                }) {
                    Text("Log Out")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(8)
                }
                .padding(.horizontal, 40)
            }
            .padding(.bottom, 40)
            .padding(.top, 10)
        }
        .navigationBarBackButtonHidden(true)
        .preferredColorScheme(.light)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    self.presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.black)
                        Text("Back")
                            .foregroundColor(.black)
                    }
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                PhotosPicker(
                    selection: $photoImportVM.selectedItems,
                    maxSelectionCount: 10,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Image(systemName: "photo.badge.plus")
                        .foregroundColor(.black)
                        .font(.body)
                }
                .padding(.trailing, 10)
            }
        }
        .task {
            await profile.refreshUserPlaces()
        }
        .onChange(of: photoImportVM.selectedItems) { _ in
            Task {
                await photoImportVM.processSelectedPhotos()
            }
        }
        .sheet(isPresented: $photoImportVM.showPlaceSelection) {
            PlaceSelectionView(photoImportVM: photoImportVM)
        }
        .sheet(isPresented: $photoImportVM.showReviewTypeSelection) {
            ReviewTypeSelectionView(
                photoImportVM: photoImportVM,
                onGenericReview: {
                    navigateToGenericReview()
                },
                onRestaurantReview: {
                    navigateToRestaurantReview()
                }
            )
        }

        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showCreateReview) {
            if let selectedPlace = photoImportVM.selectedPlace,
               !photoImportVM.selectedImages.isEmpty {
                CreatePlaceReviewView(
                    isPresented: $showCreateReview,
                    place: convertToDetailPlace(selectedPlace),
                    userId: userSession.currentUserId ?? "",
                    profilePhotoUrl: profile.user?.profilePhotoURL?.absoluteString ?? "",
                    userFirstName: profile.user?.firstName ?? "",
                    userLastName: profile.user?.lastName ?? "",
                    preselectedImages: photoImportVM.selectedImages,
                    reviewType: selectedReviewType,
                    onReviewSubmitted: { place in
                        // Navigate to place detail view after review creation
                        photoImportVM.navigateToPlaceDetail(place: place)
                    }
                )
            }
        }
        .onChange(of: photoImportVM.shouldNavigateToPlaceDetail) { shouldNavigate in
            if shouldNavigate, let place = photoImportVM.createdPlaceForDetail {
                // Set the selected place and show detail sheet
                selectedPlaceVM.selectedPlace = place
                selectedPlaceVM.isDetailSheetPresented = true
                
                // Reset the navigation flag
                photoImportVM.shouldNavigateToPlaceDetail = false
                photoImportVM.createdPlaceForDetail = nil
            }
        }
    }
    
    private func navigateToRestaurantReview() {
        selectedReviewType = .restaurant
        photoImportVM.showReviewTypeSelection = false
        showCreateReview = true
    }
    
    private func navigateToGenericReview() {
        selectedReviewType = .generic
        photoImportVM.showReviewTypeSelection = false
        showCreateReview = true
    }
    
    private func convertToDetailPlace(_ nearbyPlace: NearbyPlaceFeature) -> DetailPlace {
        var detailPlace = DetailPlace()
        // Create a consistent UUID from the actualId by hashing it
        detailPlace.id = createConsistentUUID(from: nearbyPlace.properties.actualId)
        detailPlace.name = nearbyPlace.properties.name
        detailPlace.address = nearbyPlace.properties.address
        detailPlace.coordinate = GeoPoint(
            latitude: nearbyPlace.geometry.latitude,
            longitude: nearbyPlace.geometry.longitude
        )
        detailPlace.rating = nearbyPlace.properties.rating
        detailPlace.categories = nearbyPlace.properties.types
        detailPlace.phone = nearbyPlace.properties.photoReference // This might not be correct mapping
        return detailPlace
    }
    
    private func createConsistentUUID(from string: String) -> UUID {
        // Try to parse as UUID first (for existing UUID-based places)
        if let uuid = UUID(uuidString: string) {
            return uuid
        }
        
        // For non-UUID strings (like Google Place IDs), create a consistent UUID by hashing
        // This ensures the same string always produces the same UUID
        let hash = abs(string.hashValue)
        
        // Create a deterministic UUID from the hash
        // We'll use the hash to seed the UUID generation
        let uuidString = String(format: "%08x-0000-0000-0000-%012x", hash, hash)
        
        return UUID(uuidString: uuidString) ?? UUID()
    }
}

