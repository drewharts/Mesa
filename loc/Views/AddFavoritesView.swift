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

                if let favorites = userSession.profileViewModel?.favoritePlaces,
                   !favorites.isEmpty {
                    
                    ScrollView(.horizontal) {
                        HStack(spacing: 16) {
                            ForEach(favorites) { place in
                                Text(place.name)
                                    .foregroundColor(.white)
                                    .font(.headline)
                                    .padding(8)
                                    .background(Color.blue)
                                    .cornerRadius(8)
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
            .onAppear {
                // Auto-focus the search bar
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.searchBarFocus = true
                }
            }
        }
    }
}
