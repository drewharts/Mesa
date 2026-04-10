//
//  CityAllListsView.swift
//  loc
//
//  Vertical grid view showing all lists for a city.
//

import SwiftUI

/// Full-screen vertical grid of all city lists, navigated from "See All" in city detail.
struct CityAllListsView: View {
    let lists: [CityDetailListRecord]
    @Binding var placeColors: [UUID: Color]
    let onListTap: (CityDetailListRecord) -> Void
    var onCreatorTap: ((String) -> Void)? = nil

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(lists, id: \.list_id) { list in
                    CityListTile(
                        list: list,
                        places: list.places,
                        placeColors: $placeColors,
                        onTap: { onListTap(list) },
                        onCreatorTap: onCreatorTap
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
        }
        .navigationTitle("Lists")
        .navigationBarTitleDisplayMode(.inline)
    }
}
