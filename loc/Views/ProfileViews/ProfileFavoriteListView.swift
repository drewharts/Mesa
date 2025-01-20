//
//  ProfileFavoriteListView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/22/24.
//

import SwiftUI

struct ProfileFavoriteListView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @State private var showSearch = false
    
    // Keep track of which place is currently selected
    @State private var selectedPlace: Place? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            // 1) "FAVORITES" button
            Button {
                showSearch = true
            } label: {
                Text("FAVORITES")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 20)
                    .foregroundStyle(.black)
                    .padding(.top,-10)

            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)

            
            // 2) Favorite places
            if !profile.favoritePlaces.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) { // Horizontal scrolling enabled
                    HStack {
                        ForEach(profile.favoritePlaces) { place in
                            VStack { // Place image and name vertically
                                ZStack {
                                    // If we have the photo for this place, use it
                                    if let image = profile.favoritePlaceImages[place.id] {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 85, height: 85)
                                            .cornerRadius(50)
                                            .clipped()
                                    } else {
                                        // Placeholder if we don't yet have the image
                                        Rectangle()
                                            .fill(Color.blue.opacity(0.3))
                                            .frame(width: 85, height: 85)
                                            .cornerRadius(50)
                                            .onAppear {
                                                profile.loadPhoto(for: place.id)
                                            }
                                    }
                                }
                                
                                Text(place.name.prefix(15)) // Limit to 15 characters
                                    .foregroundColor(.black)
                                    .font(.footnote)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(1)
                                    .frame(width: 85) // Fixed width
                            }
                            .padding(.trailing, 10) // Add padding between items
                            // 3) Tapping a place sets `selectedPlace`
                            .onTapGesture {
                                selectedPlace = place
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
            } else {
                Text("No lists available")
                    .foregroundColor(.gray)
                    .padding(.horizontal)
            }
            Divider()
                .padding(.top, 15)
                .padding(.horizontal, 20)

        }
        // 4) Present AddFavoritesView in a sheet
        .sheet(isPresented: $showSearch) {
            AddFavoritesView()
        }
        // 5) Present a detail sheet (or action sheet) for the selected place
        .fullScreenCover(item: $selectedPlace) { place in
            // Present the MainView.
            // Pass in the "preselected" place so we know which one to select on the map.
            MainView(locationManager: LocationManager(),   // or pass in your existing one
                     preselectedPlace: place)
                // If needed, also pass along environment objects, etc.
                .environmentObject(profile)
        }

    }
}
