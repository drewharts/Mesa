//
//  ContentView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 7/13/24.
//

// ContentView.swift
// loc

import SwiftUI
import UIKit
import GooglePlaces


struct ContentView: View {
    @StateObject private var viewModel = SearchViewModel()
    @ObservedObject var locationManager: LocationManager
    @FocusState private var searchIsFocused: Bool
    @State private var isSearchBarMinimized = false
    @State private var showDetailSheet = false
    @State private var offsetY: CGFloat = UIScreen.main.bounds.height * 0.5

    init(locationManager: LocationManager = LocationManager()) {
        self.locationManager = locationManager
    }

    var body: some View {
        ZStack(alignment: .top) {
            MapView(
                searchResults: $viewModel.searchResults,
                selectedPlace: $viewModel.selectedPlace,
                locationManager: locationManager,
                onMapTap: handleMapTap
            )
            .edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                if isSearchBarMinimized {
                    // Minimized Search Bar as a Blue Circle with a Magnifying Glass
                    Button(action: {
                        withAnimation {
                            isSearchBarMinimized.toggle()
                            searchIsFocused = true
                        }
                    }) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white)
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
                    .frame(maxWidth: .infinity, alignment: .topTrailing)
                } else {
                    // Expanded Search Bar
                    SearchBar(text: $viewModel.searchText)
                        .focused($searchIsFocused)

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
        }
        .onAppear {
            locationManager.requestLocationPermission()
        }
        
        .sheet(isPresented: $showDetailSheet) {
            if let selectedPlace = viewModel.selectedPlace {
                RestaurantDetailView(place: selectedPlace)
                    .presentationDetents([.height(100),.medium,.large])
                    .presentationBackgroundInteraction(.enabled(upThrough: .height(100)))
            }
        }
    }
    

    // Handle the map tap to minimize the search bar
    private func handleMapTap() {
        withAnimation {
            isSearchBarMinimized = true
            searchIsFocused = false
            viewModel.searchResults = []
        }
    }
    struct RestaurantDetailView: View {
        let place: GMSPlace // Accept GMSPlace directly

        var body: some View {
            VStack(spacing: 16) {
                Text(place.name ?? "Unknown") // Access name from GMSPlace
                    .font(.title)
                    .bold()
                
                Text(place.formattedAddress ?? "Unknown Address") // Access address from GMSPlace
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
            .padding()
        }
    }
}
