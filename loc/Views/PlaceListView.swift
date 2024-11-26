//
//  PlaceListView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/25/24.
//


// PlaceListView.swift

import SwiftUI
import GooglePlaces

struct PlaceListView: View {
    var placeList: PlaceList

    var body: some View {
        List {
            ForEach(placeList.places, id: \.placeID) { place in
                Text(place.name ?? "Unknown Place")
            }
        }
        .navigationTitle(placeList.name)
    }
}
