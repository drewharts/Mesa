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
            }
            .buttonStyle(.plain)
            
            // 2) Favorite places
            if !profile.favoritePlaces.isEmpty {
                HStack {
                    ForEach(profile.favoritePlaces) { place in
                        ZStack {
                            // If we have the photo for this place, use it
                            if let image = profile.favoritePlaceImages[place.id] {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .cornerRadius(8)
                                    .clipped()
                            } else {
                                // Placeholder if we don't yet have the image
                                Rectangle()
                                    .fill(Color.blue.opacity(0.3))
                                    .frame(width: 100, height: 100)
                                    .cornerRadius(8)
                                    .onAppear {
                                        profile.loadPhoto(for: place.id)
                                    }
                            }
                            
                            Text(place.name)
                                .foregroundColor(.white)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                                .padding(8)
                        }
                        // 3) Tapping a place sets `selectedPlace`
                        .onTapGesture {
                            selectedPlace = place
                        }
                    }
                }
                .padding(.horizontal, 20)
                
            } else {
                Text("No lists available")
                    .foregroundColor(.gray)
                    .padding(.horizontal)
            }
        }
        // 4) Present AddFavoritesView in a sheet
        .sheet(isPresented: $showSearch) {
            AddFavoritesView()
        }
        // 5) Present a detail sheet (or action sheet) for the selected place
        .sheet(item: $selectedPlace) { place in
            // This sheet is specifically for the selected place
            // Build a detail view (or anything you want to show)
            VStack {
                Text("Details for \(place.name)")
                    .font(.largeTitle)
                // ... show more info about `place` here ...
                Spacer()
            }
            .padding()
        }
    }
}
