//
//  ContentView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 7/13/24.
//

import SwiftUICore
import UIKit

struct ContentView: View {
    @StateObject private var viewModel = SearchViewModel()
    @ObservedObject var locationManager: LocationManager // Make this a required parameter

    init(locationManager: LocationManager = LocationManager()) {
        self.locationManager = locationManager
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Pass locationManager to MapView
            MapView(searchResults: $viewModel.searchResults, selectedPlace: $viewModel.selectedPlace, locationManager: locationManager)
                .edgesIgnoringSafeArea(.all)

            // Floating Search Bar and Search Results
            VStack {
                SearchBar(text: $viewModel.searchText)

                // Dynamic Search Results List
                if !viewModel.searchResults.isEmpty {
                    SearchResultsView(results: viewModel.searchResults) { prediction in
                        viewModel.selectPlace(prediction)
                    }
                }
            }
        }
        .onAppear {
            locationManager.requestLocationPermission()
        }
        .onTapGesture {
            hideKeyboard()
        }
    }

    // Helper function to hide the keyboard
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
