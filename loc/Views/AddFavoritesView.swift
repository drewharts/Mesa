//
//  SearchFavoritesView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/28/24.
//

import SwiftUI
import GooglePlaces  // If you’re using GMSAutocompletePrediction, etc.

struct AddFavoritesView: View {
    @EnvironmentObject var userSession: UserSession
    @StateObject private var viewModel = SearchViewModel()

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
                        // Display prediction text
                        Text(prediction.attributedPrimaryText.string)
                            .onTapGesture {
                                addPlaceToFavorites(prediction)
                            }
                    }
                    .listStyle(.plain)
                } else {
                    Text("Type to search for new places")
                        .foregroundColor(.gray)
                }
                
                Divider()
                
                // SHOW CURRENT FAVORITES
                Text("Current Favorites")
                    .font(.headline)

                if let favorites = userSession.profileViewModel?.favoritePlaces,
                   !favorites.isEmpty {
                    
                    ScrollView(.horizontal) {
                        HStack(spacing: 16) {
                            ForEach(favorites) { place in
                                Rectangle()
                                    .fill(Color.blue.opacity(0.3))
                                    .frame(width: 100, height: 100)
                                    .cornerRadius(8)
                                    .overlay(
                                        Text(place.name)
                                            .foregroundColor(.white)
                                            .font(.caption)
                                            .padding(4),
                                        alignment: .bottom
                                    )
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
        // Example: You might convert the GMSAutocompletePrediction into a Place
        // by calling GMSPlacesClient. For demonstration, let's create a dummy Place:
        
        let newPlace = Place(
            id: prediction.placeID ?? UUID().uuidString,
            name: prediction.attributedPrimaryText.string,
            address: prediction.attributedSecondaryText?.string ?? "Unknown"
        )
        
        userSession.profileViewModel?.favoritePlaces.append(newPlace)
    }
}
