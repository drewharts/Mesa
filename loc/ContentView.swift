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

    var body: some View {
        VStack {
            MapView(searchResults: $searchResults)
                .edgesIgnoringSafeArea(.all)
                .onAppear {mapViewRef = MapView(searchResults: $searchResults)}
        }
    }

}

#Preview {
    ContentView()
}
