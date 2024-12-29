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
    @StateObject private var viewModel = SearchViewModel()
    
    // Track the ID of the most recently tapped place
    @State private var lastTappedPlaceID: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                
                // SEARCH BAR
                SearchBar(text: $viewModel.searchText)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                
                // SEARCH RESULTS
                if !viewModel.searchResults.isEmpty {
                    List(viewModel.searchResults, id: \.self) { prediction in
                        // Highlight if this row's placeID matches lastTappedPlaceID
                        HStack {
                            Text(prediction.attributedPrimaryText.string)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.vertical, 6)
                        .background(
                            // If placeID matches, highlight the row
                            (prediction.placeID == lastTappedPlaceID)
                            ? Color.blue.opacity(0.2)
                            : Color.clear
                        )
                        .onTapGesture {
                            // 1) Append to favorites
                            addPlaceToFavorites(prediction)
                            
                            // 2) Highlight this row
                            lastTappedPlaceID = prediction.placeID
                            
                            // 3) If you want the highlight to go away after 2 seconds:
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation {
                                    // Clear the highlight
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

                if let favorites = userSession.profileViewModel?.favoritePlaces,
                   !favorites.isEmpty {
                    
                    ScrollView(.horizontal) {
                        HStack(spacing: 16) {
                            ForEach(favorites) { place in
                                ZStack {
                                    Text(place.name)
                                        .foregroundColor(.white)
                                        .font(.headline)
                                        .multilineTextAlignment(.center)
                                        .padding(8)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                } else {
                    Text("No favorites yet.")
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("Add to Favorites")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    /// Converts a search `prediction` into a `Place` and appends to user favorites.
    private func addPlaceToFavorites(_ prediction: GMSAutocompletePrediction) {
        let newPlace = Place(
            id: prediction.placeID ?? UUID().uuidString,
            name: prediction.attributedPrimaryText.string,
            address: prediction.attributedSecondaryText?.string ?? "Unknown"
        )
        
        userSession.profileViewModel?.addFavoritePlace(place: newPlace)
    }
}
