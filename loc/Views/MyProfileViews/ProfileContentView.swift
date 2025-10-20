//
//  ProfileContentView.swift
//  loc
//
//  Created by Claude on 1/13/25.
//

import SwiftUI
import PhotosUI

struct ProfileContentView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @ObservedObject var photoImportVM: PhotoImportViewModel
    
    @State private var showDeleteAccountConfirmation = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountError: String?
    
    var body: some View {
        let _ = print("👤 [ProfileContentView] Body computed at \(Date())")
        return ZStack {
            ScrollView {
                VStack(spacing: 12) {
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
                        profile.logout()
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
                    
                    // Delete Account Button
                    Button(action: {
                        showDeleteAccountConfirmation = true
                    }) {
                        Text("Delete Account")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.black)
                            .cornerRadius(8)
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 10)
                }
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .alert("Delete Account", isPresented: $showDeleteAccountConfirmation) {
            Button("Cancel", role: .cancel) {
                showDeleteAccountConfirmation = false
                deleteAccountError = nil
            }
            Button("Delete", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("Are you sure you want to delete your account? This action cannot be undone and will permanently remove all your data, including places, reviews, lists, and followers.")
        }
        .alert("Error", isPresented: .constant(deleteAccountError != nil)) {
            Button("OK") {
                deleteAccountError = nil
            }
        } message: {
            if let error = deleteAccountError {
                Text(error)
            }
        }
        .overlay(
            // Loading overlay
            Group {
                if isDeletingAccount {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            
                            Text("Deleting Account...")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("This may take a few moments")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(30)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(15)
                    }
                }
            }
        )
    }
    
    private func deleteAccount() {
        isDeletingAccount = true
        deleteAccountError = nil
        
        profile.deleteAccount { success, errorMessage in
            isDeletingAccount = false
            
            if success {
                // Account deletion successful - user will be logged out automatically
                showDeleteAccountConfirmation = false
            } else {
                // Show error message
                deleteAccountError = errorMessage ?? "Failed to delete account. Please try again."
            }
        }
    }
}

