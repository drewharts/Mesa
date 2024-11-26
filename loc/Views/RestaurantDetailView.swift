//
//  RestaurantDetailView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/8/24.
//

//  RestaurantDetailView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/8/24.
//

import SwiftUI
import GooglePlaces

struct RestaurantDetailView: View {
    let place: GMSPlace
    @State private var currentPlaceID: String? = nil
    @Binding var sheetHeight: CGFloat
    let minSheetHeight: CGFloat
    @State private var photos: [UIImage] = [] // Store fetched photos
    
    @EnvironmentObject var profile: Profile // Access Profile from environment
    
    @State private var showAlert = false // State to control alert visibility
    @State private var alertMessage = "" // Alert message
    
    // State for selecting an existing list
    @State private var showListSelection = false
    @State private var selectedList: PlaceList? = nil
    
    var body: some View {
        VStack(spacing: 16) {
            if sheetHeight == minSheetHeight {
                // Collapsed State Content
                Text(place.name ?? "Unknown")
                    .font(.title)
                    .foregroundColor(.gray)
                    .padding()
            } else {
                // Expanded State Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Header
                        HStack(alignment: .top, spacing: 8) { // Reduced spacing for better space management
                            if let iconURL = place.iconImageURL {
                                AsyncImage(url: iconURL) { phase in
                                    if let image = phase.image {
                                        image
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 75, height: 75)
                                            .cornerRadius(8)
                                            .padding(10)
                                    } else if phase.error != nil {
                                        Image(systemName: "photo") // Fallback for errors
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 40, height: 40)
                                            .foregroundColor(.gray)
                                    } else {
                                        ProgressView() // Loading spinner
                                            .frame(width: 40, height: 40)
                                    }
                                }
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Text(place.name ?? "Unknown")
                                    .font(.title)
                                    .foregroundStyle(.gray)
                                    .bold()
                                    .lineLimit(1) // Ensure it stays on one line
                                    .minimumScaleFactor(0.7) // Shrinks font size to fit within space
                                    .frame(maxWidth: .infinity, alignment: .leading) // Use as much space as possible

                                Button(action: {
                                    // Directions action
                                }) {
                                    Text("Directions")
                                        .font(.subheadline)
                                        .foregroundStyle(.gray)
                                        .padding(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.gray, lineWidth: 2)
                                        )
                                }
                            }

                            Button(action: {
                                handleAddButton()
                            }) {
                                Image(systemName: "plus")
                                    .padding(8)
                                    .background(Circle().fill(Color.gray.opacity(0.2)))
                                    .foregroundStyle(.black)
                            }
                            .frame(width: 40) // Fixed size for the button to ensure alignment
                        }
                        .padding(.horizontal)

                        // Photo Grid
                        if !photos.isEmpty {
                            GridView(images: photos)
                        } else {
                            ProgressView("Loading Photos...")
                                .frame(maxWidth: .infinity)
                                .padding()
                        }

                        // Address and Hours
                        VStack(alignment: .leading, spacing: 8) {
                            if let openingHours = place.currentOpeningHours?.weekdayText {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Opening Hours:")
                                        .font(.headline)
                                        .foregroundColor(.black)
                                    ForEach(openingHours, id: \.self) { hour in
                                        Text(hour)
                                            .font(.subheadline)
                                            .foregroundColor(.black)
                                    }
                                }
                            } else {
                                Text("Opening hours not available")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.horizontal)
                }
            }
        }
        .onAppear(perform: fetchPhotos) // Fetch photos when the view appears
        .onChange(of: place.placeID) { _ in
            fetchPhotos()
        }
        .padding(.vertical)
        .frame(maxWidth: .infinity)
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Success"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .sheet(isPresented: $showListSelection) {
            ListSelectionSheet(place: place, isPresented: $showListSelection)
                .environmentObject(profile) // Pass Profile as environment object
        }
    }

    private func fetchPhotos() {
        photos = []
        guard let photosMetadata = place.photos, !photosMetadata.isEmpty else {
            print("No photos metadata found.")
            return
        }

        // Track the current place
        currentPlaceID = place.placeID

        let placesClient = GMSPlacesClient.shared()

        photosMetadata.forEach { photoMetadata in
            let fetchPhotoRequest = GMSFetchPhotoRequest(photoMetadata: photoMetadata, maxSize: CGSize(width: 480, height: 480))
            
            placesClient.fetchPhoto(with: fetchPhotoRequest) { (photoImage, error) in
                if let error = error {
                    print("Error fetching photo: \(error.localizedDescription)")
                } else if let photoImage = photoImage {
                    DispatchQueue.main.async {
                        // Ensure photos belong to the current place
                        if self.currentPlaceID == self.place.placeID {
                            self.photos.append(photoImage)
                        } else {
                            print("Discarding photo for outdated place.")
                        }
                    }
                }
            }
        }
    }
    
    private func handleAddButton() {
        showListSelection = true
    }
    
    private func createNewList(named listName: String) {
        let trimmedName = listName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            alertMessage = "List name cannot be empty."
            showAlert = true
            return
        }
        
        if profile.placeLists.contains(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
            alertMessage = "A list with this name already exists."
            showAlert = true
            return
        }
        
        let newList = PlaceList(name: trimmedName)
        profile.addPlacesList(newList)
        profile.addPlace(place: place, to: newList)
        
        alertMessage = "\(place.name ?? "Place") has been added to \(trimmedName)."
        showAlert = true
    }
    
    private func addToExistingList(_ list: PlaceList) {
        profile.addPlace(place: place, to: list)
        
        alertMessage = "\(place.name ?? "Place") has been added to \(list.name)."
        showAlert = true
    }
}

struct GridView: View {
    let images: [UIImage]

    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(images.indices, id: \.self) { index in
                Image(uiImage: images[index]) // Wrap UIImage in a SwiftUI Image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 125, height: 100)
                    .clipped()
                    .cornerRadius(8)
            }
        }
    }
}
