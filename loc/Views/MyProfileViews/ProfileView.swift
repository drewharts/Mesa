//  ProfileView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/9/24.
//

import SwiftUI
import PhotosUI

struct ProfileView: View {
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var placeVM: DetailPlaceViewModel
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    @StateObject private var photoImportVM = PhotoImportViewModel()
    
    @State private var showingPhotoPicker = false

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

                // Photo Processing Display
                if let coordinates = photoImportVM.detectedCoordinates {
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
                Button(action: {
                    showingPhotoPicker = true
                }) {
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
        .sheet(isPresented: $showingPhotoPicker) {
            PhotosPicker(
                selection: $photoImportVM.selectedItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Text("Select Photo for Review")
                    .font(.headline)
                    .padding()
            }
            .onChange(of: photoImportVM.selectedItem) { _ in
                Task {
                    await photoImportVM.processSelectedPhoto()
                }
            }
        }
        .sheet(isPresented: $photoImportVM.showPlaceSelection) {
            PlaceSelectionView(photoImportVM: photoImportVM)
        }

        .navigationBarTitleDisplayMode(.inline)
    }
}

