//  MainView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/12/24.
//

import SwiftUI
import GooglePlaces
import FirebaseAuth

struct MainView: View {
    @EnvironmentObject var userSession: UserSession
    @StateObject private var viewModel = SearchViewModel()
    @StateObject private var mapViewModel: MapViewModel

    @FocusState private var searchIsFocused: Bool
    @State private var isSearchBarMinimized = true
    @State private var sheetHeight: CGFloat = 200
    @State private var minSheetHeight: CGFloat = 250
    @State private var maxSheetHeight: CGFloat = UIScreen.main.bounds.height * 0.75
    @State private var showDetailSheet = false
    @State private var showProfileView = false

    init(userSession: UserSession) {
        let locationManager = LocationManager()
        
        // Initialize SearchViewModel
        let searchVM = SearchViewModel()

        // Initialize MapViewModel with searchVM
        let mapVM = MapViewModel(locationManager: locationManager, userSession: userSession, searchViewModel: searchVM)
        
        _viewModel = StateObject(wrappedValue: searchVM)
        _mapViewModel = StateObject(wrappedValue: mapVM)
    }

    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                // Map
                MapView(viewModel: mapViewModel, searchResults: $viewModel.searchResults) {
                    handleMapTap()
                }
                .edgesIgnoringSafeArea(.all)

                // Top Controls
                VStack(spacing: 16) {
                    if isSearchBarMinimized {
                        HStack {
                            Spacer()
                            VStack(spacing: 10) {
                                // Minimized Search Bar Button
                                Button(action: {
                                    withAnimation {
                                        if sheetHeight == maxSheetHeight {
                                            sheetHeight = minSheetHeight
                                        }
                                        isSearchBarMinimized.toggle()
                                        searchIsFocused = true
                                    }
                                }) {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(.blue)
                                        .frame(width: 60, height: 60)
                                        .background(Color.white)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.gray, lineWidth: 2))
                                        .shadow(radius: 4)
                                }
                                .padding(.top, 10)
                                .padding(.trailing, 20)

                                // Profile Button
                                NavigationLink(destination: ProfileView().environmentObject(userSession), isActive: $showProfileView) {
                                    Button(action: {
                                        showProfileView = true
                                    }) {
                                        if let profilePhoto = userSession.profileViewModel?.profilePhoto {
                                            profilePhoto
                                                .resizable()
                                                .frame(width: 60, height: 60)
                                                .clipShape(Circle())
                                                .overlay(Circle().stroke(Color.gray, lineWidth: 2))
                                                .shadow(radius: 4)
                                        } else {
                                            Image(systemName: "person.crop.circle")
                                                .resizable()
                                                .foregroundColor(.blue)
                                                .frame(width: 60, height: 60)
                                                .background(Color.white)
                                                .clipShape(Circle())
                                                .overlay(Circle().stroke(Color.gray, lineWidth: 2))
                                                .shadow(radius: 4)
                                        }
                                    }
                                }
                                .padding(.trailing, 20)
                            }
                        }
                    } else {
                        // Expanded Search Bar
                        SearchBar(text: $viewModel.searchText)
                            .focused($searchIsFocused)
                            .padding(.horizontal, 20)
                            .padding(.top, 10)

                        if !viewModel.searchResults.isEmpty {
                            SearchResultsView(results: viewModel.searchResults) { prediction in
                                viewModel.selectPlace(prediction)
                                //mapViewModel.selectedPlace = viewModel.selectedPlace
                                withAnimation {
                                    isSearchBarMinimized = true
                                    searchIsFocused = false
                                    showDetailSheet = true
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 20)
                            .padding(.top, 10)
                        }
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))

                // Bottom Sheet
                if showDetailSheet, let selectedPlace = mapViewModel.selectedPlace {
                    BottomSheetView(
                        isPresented: $showDetailSheet,
                        sheetHeight: $sheetHeight,
                        maxSheetHeight: maxSheetHeight
                    ) {
                        PlaceDetailView(
                            place: selectedPlace,
                            sheetHeight: $sheetHeight,
                            minSheetHeight: minSheetHeight
                        )
                        .frame(maxWidth: .infinity)
                        .id(selectedPlace.placeID)
                    }
                }
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }

    private func handleMapTap() {
        withAnimation {
            searchIsFocused = false
            viewModel.searchResults = []
            isSearchBarMinimized = true
        }
    }
}
