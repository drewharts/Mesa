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
    @EnvironmentObject var userSession: UserSession

    var body: some View {
        List {
            ForEach(placeList.places, id: \.id) { place in
                HStack(spacing: 16) {
                    if let image = userSession.profileViewModel?.favoritePlaceImages[place.id] {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .cornerRadius(8)
                            .clipped()
                    } else {
                        // Placeholder if we don't yet have the image
                        Rectangle()
                            .fill(Color.blue.opacity(0.3))
                            .frame(width: 80, height: 80)
                            .cornerRadius(8)
                            .onAppear {
                                userSession.profileViewModel?.loadPhoto(for: place.id)
                            }
                    }
                    
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



