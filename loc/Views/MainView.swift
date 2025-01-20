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
    // MARK: - Dependencies
    @EnvironmentObject var userSession: UserSession
    
    // Location manager
    @ObservedObject var locationManager: LocationManager

    // Our custom search VM that handles text, predictions, etc.
    @StateObject private var viewModel = SearchViewModel()

    // MARK: - Preselected Place (from favorites)
    /// The custom `Place` you tapped in ProfileFavoriteListView,
    /// if any. Use this to fetch a `GMSPlace` on appear.
    let preselectedPlace: Place?

    // MARK: - Search UI States
    @FocusState private var searchIsFocused: Bool
    @State private var isSearchBarMinimized = true

    // MARK: - Sheet Controls
    @State private var sheetHeight: CGFloat = 200
    @State private var minSheetHeight: CGFloat = 250
    @State private var maxSheetHeight: CGFloat = UIScreen.main.bounds.height * 0.75
    @State private var showDetailSheet = false

    // MARK: - Profile
    @State private var showProfileView = false

    // MARK: - Init
    init(locationManager: LocationManager = LocationManager(),
         preselectedPlace: Place? = nil)
    {
        self.locationManager = locationManager
        self._viewModel = StateObject(wrappedValue: SearchViewModel())
        self.preselectedPlace = preselectedPlace
    }

    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                
                // 1) The map
                MapView(
                    searchResults: $viewModel.searchResults,
                    selectedPlace: $viewModel.selectedPlace, // GMSPlace?
                    locationManager: locationManager,
                    onMapTap: handleMapTap
                )
                .edgesIgnoringSafeArea(.all)

                // 2) Top Controls (Search Bar + Profile Button)
                VStack(spacing: 16) {
                    if isSearchBarMinimized {
                        HStack {
                            Spacer()
                            
                            VStack(spacing: 10) {
                                // Minimized Search Button
                                Button(action: {
                                    withAnimation {
                                        // If the sheet is currently at max height, shrink it
                                        if sheetHeight == maxSheetHeight {
                                            sheetHeight = minSheetHeight
                                        }
                                        // Then expand the search bar
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
                                NavigationLink(destination: ProfileView(),
                                               isActive: $showProfileView) {
                                    Button(action: {
                                        showProfileView = true
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
                            SearchResultsView(results: viewModel.searchResults) { prediction in
                                viewModel.selectPlace(prediction)
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

                // 3) Bottom Sheet for the selected place
                if showDetailSheet, let selectedPlace = viewModel.selectedPlace {
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
                        // Force SwiftUI to re-render if the place ID changes
                        .id(selectedPlace.placeID)
                    }
                }
            }
            .onAppear {
                // Request permission
                locationManager.requestLocationPermission()
                
                // If we arrived with a "favorite" place from the profile screen
                if let favorite = preselectedPlace {
                    // Force the detail sheet open at max size
                    self.sheetHeight = maxSheetHeight
                    self.showDetailSheet = true
                    
                    // (A) If you store the entire GMSPlace in `favorite`
                    //     you can just do:
                    // viewModel.selectedPlace = favorite.gmsPlace

                    // (B) If you only have the ID, do an async fetch:
                    fetchFullGMSPlace(by: favorite.id) { gmsPlace in
                        // Assign once retrieved
                        self.viewModel.selectedPlace = gmsPlace
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - Handle Tap on the Map
    private func handleMapTap() {
        withAnimation {
            searchIsFocused = false
            viewModel.searchResults = []
            isSearchBarMinimized = true
        }
    }

    // MARK: - Example of an async fetch for the GMSPlace from an ID
    private func fetchFullGMSPlace(by placeID: String, completion: @escaping (GMSPlace?) -> Void) {
        // For example, if you have a service:
        //   GooglePlacesService.shared.fetchPlace(placeID: placeID) { place, error in
        //       if let place = place {
        //           completion(place)
        //       } else {
        //           completion(nil)
        //       }
        //   }

        // Here’s a quick mock for demonstration:
        let fields: GMSPlaceField = .all
        GMSPlacesClient.shared().fetchPlace(fromPlaceID: placeID, placeFields: fields, sessionToken: nil) { place, error in
            if let error = error {
                print("Error fetching place: \(error)")
                completion(nil)
                return
            }
            completion(place)
        }
    }
}
