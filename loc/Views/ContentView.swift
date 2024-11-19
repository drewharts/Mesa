// ContentView.swift
// loc

import SwiftUI
import UIKit
import GooglePlaces
import FirebaseAuth

struct ContentView: View {
    @EnvironmentObject var userSession: UserSession // Access UserSession for login state
    @StateObject private var viewModel = SearchViewModel()
    @ObservedObject var locationManager: LocationManager
    @FocusState private var searchIsFocused: Bool
    @State private var isSearchBarMinimized = true
    @State private var sheetHeight: CGFloat = 200 // Initial height of the bottom sheet
    @State private var minSheetHeight: CGFloat = 200 // Minimum height
    @State private var maxSheetHeight: CGFloat = UIScreen.main.bounds.height * 0.6 // Max height for the sheet
    @State private var showDetailSheet = false // Controls visibility of the BottomSheetView
    @State private var showProfileView = false // Controls navigation to the Profile view

    init(locationManager: LocationManager = LocationManager()) {
        self.locationManager = locationManager
    }

    var body: some View {
        // Show the LoginView if the user is not logged in
        Group {
            if userSession.isUserLoggedIn {
                // Main app content after login
                NavigationView {
                    ZStack(alignment: .top) {
                        MapView(
                            searchResults: $viewModel.searchResults,
                            selectedPlace: $viewModel.selectedPlace,
                            locationManager: locationManager,
                            onMapTap: handleMapTap
                        )
                        .edgesIgnoringSafeArea(.all)
                        
                        VStack(spacing: 16) {
                            if isSearchBarMinimized {
                                HStack {
                                    Spacer()
                                    
                                    VStack(spacing: 10) {
                                        // Minimized Search Bar Button
                                        Button(action: {
                                            withAnimation {
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
                                            }) {
                                                if let profilePhotoURL = userSession.user?.profilePhotoURL {
                                                    AsyncImage(url: profilePhotoURL) { image in
                                                        image.resizable()
                                                    } placeholder: {
                                                        Image(systemName: "person.crop.circle")
                                                            .resizable()
                                                            .foregroundColor(.blue)
                                                    }
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
                        
                        // Custom Bottom Sheet
                        if showDetailSheet, let selectedPlace = viewModel.selectedPlace {
                            BottomSheetView(
                                isPresented: $showDetailSheet,
                                sheetHeight: $sheetHeight,
                                maxSheetHeight: maxSheetHeight
                            ) {
                                RestaurantDetailView(
                                    place: selectedPlace,
                                    sheetHeight: $sheetHeight,
                                    minSheetHeight: minSheetHeight
                                )
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .onAppear {
                        locationManager.requestLocationPermission()
                    }
                }
                .navigationViewStyle(StackNavigationViewStyle()) // Ensures proper navigation behavior
            } else {
                // Show LoginView if user is not logged in
                LoginView()
            }
        }
    }

    // Handle the map tap to minimize the search bar
    private func handleMapTap() {
        withAnimation {
            searchIsFocused = false
            viewModel.searchResults = []
            isSearchBarMinimized = true // Ensure the search bar is minimized when tapping the map
        }
    }
}
