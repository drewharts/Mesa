//
//  SearchContainerView.swift
//  loc
//
//  Created by Cursor on 11/13/25.
//

import SwiftUI

/// Container that owns SearchViewModel and handles search functionality
struct SearchContainerView: View {
    @StateObject private var searchViewModel: SearchViewModel
    @EnvironmentObject var appCoordinator: AppCoordinator
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var locationManager: LocationManager
    
    @FocusState private var searchIsFocused: Bool
    @Binding var isSearchExpanded: Bool
    
    let onPlaceSelected: () -> Void
    let onUserSelected: (ProfileData) -> Void
    
    init(
        isSearchExpanded: Binding<Bool>,
        placeService: PlaceService,
        userService: UserService,
        locationManager: LocationManager,
        selectedPlaceViewModel: SelectedPlaceViewModel,
        onPlaceSelected: @escaping () -> Void,
        onUserSelected: @escaping (ProfileData) -> Void
    ) {
        self._isSearchExpanded = isSearchExpanded
        self.onPlaceSelected = onPlaceSelected
        self.onUserSelected = onUserSelected
        
        // Create SearchViewModel scoped to this container
        let searchVM = SearchViewModel(
            placeService: placeService,
            userService: userService,
            locationManager: locationManager
        )
        searchVM.selectedPlaceVM = selectedPlaceViewModel
        self._searchViewModel = StateObject(wrappedValue: searchVM)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            searchBar
            searchResults
        }
        .onAppear {
            // Clear search text when appearing
            searchViewModel.searchText = ""
        }
    }
    
    private var searchBar: some View {
        TextField("Search here...", text: $searchViewModel.searchText)
            .padding()
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 3)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .foregroundStyle(Color.gray)
            .focused($searchIsFocused)
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, -10)
            .onTapGesture {
                searchIsFocused = true
            }
    }
    
    private var searchResults: some View {
        Group {
            if !searchViewModel.searchResults.isEmpty || 
               !searchViewModel.userResults.isEmpty || 
               searchViewModel.showNoPlaceFound || 
               searchViewModel.isSearching {
                SearchResultsView(
                    placeResults: searchViewModel.searchResults,
                    userResults: searchViewModel.userResults,
                    showNoPlaceFound: searchViewModel.showNoPlaceFound,
                    searchText: searchViewModel.searchText,
                    isSearching: searchViewModel.isSearching,
                    onSelectPlace: { prediction in
                        searchViewModel.selectSuggestion(prediction)
                        withAnimation {
                            isSearchExpanded = false
                            searchIsFocused = false
                        }
                        onPlaceSelected()
                    },
                    onSelectUser: { user in
                        onUserSelected(user)
                        withAnimation {
                            isSearchExpanded = false
                            searchIsFocused = false
                        }
                    },
                    searchViewModel: searchViewModel
                )
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 50)
            }
        }
    }
}

