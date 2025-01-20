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
    @FocusState private var searchBarFocus: Bool
    
    @State private var lastTappedPlaceID: String?
    @State private var showAlert: Bool = false // Add a state for the alert

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                
                // SEARCH BAR
                SearchBar(text: $viewModel.searchText)
                    .focused($searchBarFocus)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                
                // Current Favorites
                
                CurrentFavoritesView()
                
                // SEARCH RESULTS
                AddFavoritesSearchResultsView()
            }
            .navigationTitle("Add to Favorites")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Auto-focus the search bar
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.searchBarFocus = true
                }
            }
            // Alert to notify user if they’ve hit the 4-favorite limit
            .alert("Max Favorites Reached", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("You already have 4 favorites. Remove one before adding a new one.")
            }
        }
    }
}
