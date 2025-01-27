//
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
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @ObservedObject var locationManager: LocationManager
    @StateObject private var viewModel = SearchViewModel()

    @FocusState private var searchIsFocused: Bool
    @State private var isSearchBarMinimized = true
    @State private var sheetHeight: CGFloat = 200
    @State private var minSheetHeight: CGFloat = 250
    @State private var maxSheetHeight: CGFloat = UIScreen.main.bounds.height * 0.75
    @State private var showProfileView = false

    init(locationManager: LocationManager = LocationManager()) {
        self.locationManager = locationManager
    }

    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                // Map
                MapView(
                    searchResults: $viewModel.searchResults,
                    locationManager: locationManager,
                    onMapTap: handleMapTap
                )
                .edgesIgnoringSafeArea(.all)

                // Top Controls (Search Bar and Profile Button)
                VStack(spacing: 16) {
                    if isSearchBarMinimized {
                        HStack {
                            Spacer()

                            VStack(spacing: 10) {
                                // Minimized Search Bar Button
                                Button(action: {
                                    withAnimation {
                                        // If the sheet is currently at max height, bring it back to the min height
                                        if sheetHeight == maxSheetHeight {
                                            sheetHeight = minSheetHeight
                                        }
                                        
                                        // Now handle showing the expanded search bar
                                        isSearchBarMinimized.toggle()
                                        searchIsFocused = true
                                    }
                                }) {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(.blue)
                                        .frame(width: 60, height: 60)
                                        .background(Color.white)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle().stroke(Color.gray, lineWidth: 2)
                                        )
                                        .shadow(radius: 4)
                                }
                                .padding(.top, 10)
                                .padding(.trailing, 20)


                                // Profile Button
                                NavigationLink(destination: ProfileView(), isActive: $showProfileView) {
                                    Button(action: {
                                        showProfileView = true
                                        selectedPlaceVM.isDetailSheetPresented = false
                                    }) {
                                        if let profilePhoto = userSession.profileViewModel?.profilePhoto {
                                            profilePhoto
                                                .resizable()
                                                .frame(width: 60, height: 60)
                                                .clipShape(Circle())
                                                .overlay(
                                                    Circle().stroke(Color.gray, lineWidth: 2)
                                                )
                                                .shadow(radius: 4)
                                        } else {
                                            Image(systemName: "person.crop.circle")
                                                .resizable()
                                                .foregroundColor(.blue)
                                                .frame(width: 60, height: 60)
                                                .background(Color.white)
                                                .clipShape(Circle())
                                                .overlay(
                                                    Circle().stroke(Color.gray, lineWidth: 2)
                                                )
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
                            //this is where place is selected from search results
                            SearchResultsView(results: viewModel.searchResults) { prediction in
                                viewModel.selectPlace(prediction)
                                withAnimation {
                                    isSearchBarMinimized = true
                                    searchIsFocused = false
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
                if selectedPlaceVM.isDetailSheetPresented {
                    BottomSheetView(
                        isPresented: $selectedPlaceVM.isDetailSheetPresented,
                        sheetHeight: $sheetHeight,
                        maxSheetHeight: maxSheetHeight
                    ) {
                        PlaceDetailView(
                            sheetHeight: $sheetHeight,
                            minSheetHeight: minSheetHeight
                        )
                        .frame(maxWidth: .infinity)
//                        .id(selectedPlace.placeID) 
                    }
                }
            }
            .onAppear {
                locationManager.requestLocationPermission()
                viewModel.selectedPlaceVM = selectedPlaceVM

            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // Handle the map tap to minimize the search bar
    private func handleMapTap() {
        withAnimation {
            searchIsFocused = false
            viewModel.searchResults = []
            isSearchBarMinimized = true
        }
    }
}
