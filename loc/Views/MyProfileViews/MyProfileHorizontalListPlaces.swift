//
//  MyProfileHorizontalListPlaces.swift
//  loc
//
//  Created by Andrew Hartsfield II on 5/29/25.
//
import SwiftUI

struct MyProfileHorizontalListPlaces: View {
    @EnvironmentObject var viewModel: ProfileViewModel
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @Environment(\.presentationMode) var presentationMode

    let listId: UUID
    @Binding var placeColors: [UUID: Color]
    
    var places: [DetailPlace] {
        guard let placeIds = viewModel.userListsPlaces[listId.uuidString] else { return [] }
        return placeIds.compactMap { detailPlaceViewModel.places[$0] }
    }

    var body: some View {
        HStack {
            ForEach(places, id: \.id) { place in
                Button(action: {
                    selectedPlaceVM.selectedPlace = place
                    selectedPlaceVM.isDetailSheetPresented = true
                    presentationMode.wrappedValue.dismiss()
                }) {
                    VStack(spacing: 4) {
                        if let image = detailPlaceViewModel.placeImages[place.id.uuidString] {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 85, height: 85)
                                .cornerRadius(50)
                                .clipped()
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 1)
                                        .frame(width: 85, height: 85)
                                )
                                .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                        } else {
                            Circle()
                                .frame(width: 85, height: 85)
                                .foregroundColor(detailPlaceViewModel.colorForPlace(placeId: place.id.uuidString))
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 1)
                                        .frame(width: 85, height: 85)
                                )
                                .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                        }
                        
                        Text(place.name.prefix(15))
                            .foregroundColor(.black)
                            .fontWeight(.semibold)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                            .frame(width: 85)
                        
                        // Display restaurant type instead of city
                        if let type = detailPlaceViewModel.placeTypes[place.id.uuidString] {
                            Text(type.prefix(15))
                                .foregroundColor(.black)
                                .font(.caption)
                                .fontWeight(.light)
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                                .frame(width: 85)
                        } else if let city = place.city {
                            Text(city.prefix(15))
                                .foregroundColor(.black)
                                .font(.caption)
                                .fontWeight(.light)
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                                .frame(width: 85)
                        }
                    }
                    .padding(.trailing, 10)
                }
            }
        }
        .padding(.horizontal, 20)
        .onAppear {
            for place in places {
                if placeColors[place.id] == nil {
                    placeColors[place.id] = Color(
                        red: Double.random(in: 0...1),
                        green: Double.random(in: 0...1),
                        blue: Double.random(in: 0...1)
                    )
                }
            }
        }
    }
}
