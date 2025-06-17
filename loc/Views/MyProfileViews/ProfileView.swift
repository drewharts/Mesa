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
                    showingPhotoPicker = false
                }
            }
        }
        .alert("Location Detection", isPresented: $photoImportVM.showLocationAlert) {
            Button("OK") { }
        } message: {
            Text("Location access is required to detect places from photos. Please enable location access in Settings.")
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
