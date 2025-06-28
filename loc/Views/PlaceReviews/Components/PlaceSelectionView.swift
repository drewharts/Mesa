//  PlaceSelectionView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/12/24.
//

import SwiftUI
import CoreLocation

struct PlaceSelectionView: View {
    @ObservedObject var photoImportVM: PhotoImportViewModel
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var detailPlaceVM: DetailPlaceViewModel
    
    @State private var showCreatePlacePopup = false
    @State private var newPlaceName = ""
    @State private var newPlaceDescription = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("📍 Select a Place")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                    
                    if photoImportVM.nearbyPlaces.isEmpty {
                        Text("No places found near your photo")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Text("(searched within \(photoImportVM.searchRadiusUsed)m)")
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.7))
                        Text("Create a new place at this location")
                            .font(.caption)
                            .foregroundColor(.blue)
                    } else {
                        Text("Found \(photoImportVM.nearbyPlaces.count) places near your photo")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        if photoImportVM.searchRadiusUsed > 50 {
                            Text("(expanded search to \(photoImportVM.searchRadiusUsed)m)")
                                .font(.caption)
                                .foregroundColor(.blue)
                        } else {
                            Text("(within \(photoImportVM.searchRadiusUsed)m)")
                                .font(.caption)
                                .foregroundColor(.gray.opacity(0.7))
                        }
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)
                
                // Places List, Loading State, or Empty State
                if photoImportVM.isProcessingPhoto || photoImportVM.isLoadingNearbyPlaces {
                    VStack(spacing: 20) {
                        Spacer()
                        
                        ProgressView()
                            .scaleEffect(1.2)
                        
                        VStack(spacing: 8) {
                            if photoImportVM.isProcessingPhoto {
                                Text("Processing Photos...")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.gray)
                                
                                Text("Extracting location data from your photos")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            } else {
                                Text("Finding Nearby Places...")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.gray)
                                
                                Text("Searching for places near your photo location")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        
                        Spacer()
                    }
                } else if photoImportVM.nearbyPlaces.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                        
                        Image(systemName: "location.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.5))
                        
                        VStack(spacing: 8) {
                            Text("No places found")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.gray)
                            
                            Text("Create a new place at the location where this photo was taken")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(photoImportVM.nearbyPlaces) { place in
                                PlaceSelectionRowView(
                                    place: place,
                                    onSelect: {
                                        photoImportVM.selectPlace(place)
                                    },
                                    isLoading: photoImportVM.isSavingPlace
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                }
                
                // Create New Place Button
                Button(action: {
                    showCreatePlacePopup = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Create New Place")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .overlay(
                // Create place popup overlay
                Group {
                    if showCreatePlacePopup, let coordinate = photoImportVM.detectedCoordinates {
                        Color.black.opacity(0.3)
                            .edgesIgnoringSafeArea(.all)
                            .onTapGesture { showCreatePlacePopup = false }
                        
                        CreatePlacePopupView(
                            isPresented: $showCreatePlacePopup,
                            placeName: $newPlaceName,
                            placeDescription: $newPlaceDescription,
                            coordinate: CLLocationCoordinate2D(
                                latitude: coordinate.latitude,
                                longitude: coordinate.longitude
                            )
                        ) { name, description in
                            createNewPlace(name: name, description: description, coordinate: coordinate)
                        }
                        .frame(maxWidth: 400)
                        .zIndex(2)
                    }
                }
            )
        }
    }
    
    private func createNewPlace(name: String, description: String?, coordinate: (latitude: Double, longitude: Double)) {
        if let userId = profile.user?.id {
            // Create the coordinate
            let clCoordinate = CLLocationCoordinate2D(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            
            // Use the existing createNewPlace method from SelectedPlaceViewModel
            selectedPlaceVM.createNewPlace(
                name: name,
                description: description,
                coordinate: clCoordinate,
                userId: userId,
                profileVM: profile,
                detailPlaceVM: detailPlaceVM
            )
            
            // Create a temporary NearbyPlaceFeature from the new place
            let newNearbyPlace = createNearbyPlaceFeature(name: name, description: description, coordinate: coordinate)
            
            // Select the newly created place
            photoImportVM.selectPlace(newNearbyPlace)
            
            // Reset popup fields
            newPlaceName = ""
            newPlaceDescription = ""
        }
    }
    
    private func createNearbyPlaceFeature(name: String, description: String?, coordinate: (latitude: Double, longitude: Double)) -> NearbyPlaceFeature {
        // Create a temporary NearbyPlaceFeature for the newly created place
        let properties = NearbyPlaceProperties(
            address: description ?? "User created location",
            distanceMeters: 0,
            name: name,
            source: "user_created",
            businessStatus: nil,
            createdAt: nil,
            openNow: nil,
            permanentlyClosed: nil,
            photoReference: nil,
            priceLevel: nil,
            rating: nil,
            types: nil,
            updatedAt: nil,
            userRatingsTotal: nil,
            description: description,
            id: UUID().uuidString,
            placeId: nil
        )
        
        let geometry = NearbyPlaceGeometry(
            coordinates: [coordinate.longitude, coordinate.latitude],
            type: "Point"
        )
        
        return NearbyPlaceFeature(
            geometry: geometry,
            properties: properties,
            type: "Feature"
        )
    }
} 