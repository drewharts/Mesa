//
//  ContentView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 7/13/24.
//

import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var viewModel = SearchViewModel()
    @ObservedObject var locationManager: LocationManager

    init(locationManager: LocationManager = LocationManager()) {
        self.locationManager = locationManager
    }

    var body: some View {
        ZStack(alignment: .top) {
            MapView(searchResults: $viewModel.searchResults, selectedPlace: $viewModel.selectedPlace, locationManager: locationManager)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    hideKeyboard()
                    viewModel.searchResults = [] // Clear search results when tapping on the map
                }

            VStack(spacing: 0) {
                SearchBar(text: $viewModel.searchText)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)

                if !viewModel.searchResults.isEmpty {
                    SearchResultsView(results: viewModel.searchResults) { prediction in
                        viewModel.selectPlace(prediction)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                }
            }
            .padding(.top, 40)
        }
        .onAppear {
            locationManager.requestLocationPermission()
        }
    }

    // Helper function to hide the keyboard
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}




