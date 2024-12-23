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
                HStack(spacing: 16) {
                    Rectangle()
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(place.name)
                            .font(.body)
                        Text(place.address)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .navigationTitle(placeList.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    // Share button placeholder action
                }) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
    }
}



