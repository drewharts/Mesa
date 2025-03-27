//
//  PlaceListView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/25/24.
//


// PlaceListView.swift

import SwiftUI
import MapboxSearch

struct WidePlaceView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var places: DetailPlaceViewModel
    let place: DetailPlace
    
    var body: some View {
        HStack(spacing: 16) {
            if let image = places.placeImages[place.id.uuidString] {
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
//                    .onAppear {
//                        profile.loadPhoto(for: place.id)
//                    }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(.body)
                    .foregroundStyle(.black)
                Text(place.address!)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
    }
}

struct PlaceListView: View {
    var places: [DetailPlace]
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @Environment(\.presentationMode) var presentationMode // For dismissing the sheet

    var body: some View {
        List {
            ForEach(places, id: \.id) { place in
                // Wrap the row in a Button (or NavigationLink) so it’s tappable
                Button(action: {
                    selectedPlaceVM.selectedPlace = place
                    selectedPlaceVM.isDetailSheetPresented = true
                    presentationMode.wrappedValue.dismiss()
                }) {
                    // Existing row layout
                    WidePlaceView(place: place)
                }
                // Use a plain button style if you don't want the default highlight
                .buttonStyle(.plain)
                .listRowBackground(Color.white)       // Make each row's background white
                .listRowSeparator(.hidden)
            }
        }
//        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
//            Button(role: .destructive) {
//                profile.removePlaceFromList(place: place)
//            } label: {
//                Label("Delete", systemImage: "trash")
//            }
//        }
        // Use .plain style to remove extra insets
        .listStyle(.plain)
        // Hide default scroll content background so our custom background can show through
        .scrollContentBackground(.hidden)
        // Make the entire list background white
        .background(Color.white)
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
