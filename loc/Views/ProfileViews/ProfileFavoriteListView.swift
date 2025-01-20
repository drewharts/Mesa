//
//  ProfileFavoriteListView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/22/24.
//

import SwiftUI

struct ProfileFavoriteListView: View {
    @EnvironmentObject var userSession: UserSession // Use userSession
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
            // Access favoritePlaces through userSession
            if let profileViewModel = userSession.profileViewModel, !profileViewModel.favoritePlaces.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) { // Horizontal scrolling enabled
                    HStack {
                        ForEach(profileViewModel.favoritePlaces) { place in
                            VStack { // Place image and name vertically
                                ZStack {
                                    // If we have the photo for this place, use it
                                    // Access images through userSession
                                    if let image = profileViewModel.favoritePlaceImages[place.id] {
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
                                                // Load the photo using the profileViewModel
                                                profileViewModel.loadPhoto(for: place.id)
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
            // Make sure AddFavoritesView can access userSession
            AddFavoritesView().environmentObject(userSession)
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
