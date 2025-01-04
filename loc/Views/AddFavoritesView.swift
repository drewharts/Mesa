//
//  SearchFavoritesView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/28/24.
//

import SwiftUI
import GooglePlaces

struct AddFavoritesView: View {
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var profile: ProfileViewModel  // Using the ProfileViewModel directly
    
    @StateObject private var viewModel = SearchViewModel()
    @FocusState private var searchBarFocus: Bool
    
    @State private var lastTappedPlaceID: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                
                // SEARCH BAR
                SearchBar(text: $viewModel.searchText)
                    .focused($searchBarFocus)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                
                // SEARCH RESULTS
                if !viewModel.searchResults.isEmpty {
                    List(viewModel.searchResults, id: \.self) { prediction in
                        HStack {
                            Text(prediction.attributedPrimaryText.string)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.vertical, 6)
                        .background(
                            prediction.placeID == lastTappedPlaceID
                                ? Color.blue.opacity(0.2)
                                : Color.clear
                        )
                        .onTapGesture {
                            // 1) Append to favorites (directly via ProfileViewModel)
                            profile.addFavoritePlace(prediction: prediction)
                            
                            // 2) Highlight this row
                            lastTappedPlaceID = prediction.placeID
                            
                            // 3) Clear highlight after 2 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation {
                                    lastTappedPlaceID = nil
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                } else {
                    Text("Type to search for new places")
                        .foregroundColor(.gray)
                }
                
                Divider()
                
                // Current Favorites
                Text("Current Favorites")
                    .font(.headline)

                if profile.favoritePlaces.isEmpty {
                    // If the array is empty, show "No favorites" message
                    Text("No favorites yet.")
                        .foregroundColor(.gray)
                } else {
                    // Otherwise, show the favorites in a horizontal scroll
                    ScrollView(.horizontal) {
                        HStack(spacing: 16) {
                            ForEach(profile.favoritePlaces) { place in
                                // Blue box with the restaurant name and "X" icon
                                HStack {
                                    // Restaurant name
                                    Text(place.name)
                                        .foregroundColor(.white)
                                        .font(.headline)
                                        .padding(.leading, 8) // Add leading padding for text
                                    
                                    Spacer()
                                    
                                    // "X" icon
                                    Button(action: {
                                        // Remove the selected favorite
                                        profile.removeFavoritePlace(place: place)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.white)
                                            .font(.headline) // Match font size for better proportions
                                    }
                                    .padding(.trailing, 8) // Add trailing padding for the icon
                                }
                                .padding(.vertical, 8) // Vertical padding inside the blue box
                                .background(Color.blue)
                                .cornerRadius(8)
                            }
                        }

                        .padding(.horizontal, 20)
                    }
                }

            }
            .navigationTitle("Add to Favorites")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Auto-focus the search bar
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.searchBarFocus = true
                }
            }
        }
        // 4) Alert to notify user if they’ve hit the 4-favorite limit
        .alert("Max Favorites Reached", isPresented: $profile.showMaxFavoritesAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You already have 4 favorites. Remove one before adding a new one.")
        }
    }
}
