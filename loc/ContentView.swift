//
//  ContentView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 7/13/24.
//

import SwiftUI
import GoogleMaps
import GooglePlaces

struct ContentView: View {
    @State private var searchText = ""
    @State private var searchResults: [GMSAutocompletePrediction] = []
    @State private var mapViewRef: MapView?
    @State private var selectedPlace: GMSPlace?

    var body: some View {
        ZStack(alignment: .top) {
            // Map View
            MapView(searchResults: $searchResults, selectedPlace: $selectedPlace)
                .edgesIgnoringSafeArea(.all)
                .onAppear { mapViewRef = MapView(searchResults: $searchResults, selectedPlace: $selectedPlace) }

            // Floating Search Bar
            VStack {
                TextField("Search here...", text: $searchText, onEditingChanged: { isEditing in
                    if !isEditing {
                        self.searchResults.removeAll()
                    }
                }, onCommit: {
                    fetchAutocompleteResults()
                })
                .padding()
                .background(Color.white)
                .cornerRadius(10)
                .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 3)
                .padding(.horizontal, 20)
                .padding(.top, 40)
                .foregroundStyle(Color.black)

                // Search Results List
                if !searchResults.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(searchResults, id: \.placeID) { result in
                                Button(action: {
                                    self.selectPlace(result)
                                }) {
                                    VStack(alignment: .leading) {
                                        Text(result.attributedPrimaryText.string)
                                            .font(.headline)
                                            .foregroundColor(.black)
                                        
                                        if let secondaryText = result.attributedSecondaryText?.string {
                                            Text(secondaryText)
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(10)
                                    .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                                    .padding(.horizontal, 10)
                                }
                            }
                        }
                        .padding(.top, 10)
                    }
                    .background(Color.white.opacity(0.9))
                    .cornerRadius(10)
                    .padding(.horizontal, 20)
                }
            }
        }
        // Dismiss keyboard when tapping outside the search bar
        .onTapGesture {
            hideKeyboard()
        }
    }

    // Helper function to fetch autocomplete results
    func fetchAutocompleteResults() {
        let placesClient = GMSPlacesClient.shared()
        let filter = GMSAutocompleteFilter()
        filter.type = .establishment // or .geocode for general addresses
        placesClient.findAutocompletePredictions(fromQuery: searchText, filter: filter, sessionToken: nil) { results, error in
            if let error = error {
                print("Error fetching autocomplete results: \(error)")
                return
            }
            self.searchResults = results ?? []
        }
    }

    // Helper function to select a place
    func selectPlace(_ prediction: GMSAutocompletePrediction) {
        let placesClient = GMSPlacesClient.shared()
        placesClient.fetchPlace(fromPlaceID: prediction.placeID, placeFields: .all, sessionToken: nil) { place, error in
            if let error = error {
                print("Error fetching place details: \(error)")
                return
            }
            self.selectedPlace = place
            self.searchResults.removeAll()
        }
    }

    // Helper function to hide the keyboard
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

#Preview {
    ContentView()
}

