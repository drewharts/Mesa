//
//  CityAllPlacesView.swift
//  loc
//
//  Vertical grid view showing all popular places for a city.
//

import SwiftUI

/// Full-screen vertical grid of all city places, navigated from "See All" in city detail.
struct CityAllPlacesView: View {
    let places: [CityTopPlace]
    let onPlaceTap: (CityTopPlace) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(places) { place in
                    CityPlaceTile(place: place, onTap: { onPlaceTap(place) })
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
        }
        .navigationTitle("Popular Places")
        .navigationBarTitleDisplayMode(.inline)
    }
}
