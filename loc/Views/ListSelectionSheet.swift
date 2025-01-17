//
//  ListSelectionSheet.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/25/24.
//

import SwiftUI
import GooglePlaces

struct ListSelectionSheet: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var lists: PlaceListViewModel
    let place: GMSPlace
    @Binding var isPresented: Bool
    @State private var showNewListSheet = false
    @State private var newListName = ""
    @State public var searchText = ""
    @State private var selectedListIds: Set<UUID> = [] // Track multiple selected lists

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Spacer()

                Text("Save to list")
                    .font(.headline)
                    .padding(.leading, 20)

                Spacer()

                Button(action: {
                    showNewListSheet = true
                }) {
                    Image(systemName: "plus")
                        .imageScale(.small)
                        .foregroundColor(.black)
                        .padding(8)
                        .background(Circle().fill(.white))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            SkinnySearchBar()
            
            if !profile.placeListViewModels.isEmpty {
                ScrollView {
                    ForEach(profile.placeListViewModels) { listVM in
                        Button(action: {
                            if selectedListIds.contains(listVM.placeList.id) {
                                // Deselect the list if already selected
                                selectedListIds.remove(listVM.placeList.id)
                            } else {
                                // Select the list and add the place
                                selectedListIds.insert(listVM.placeList.id)
                                profile.getPlaceListViewModel(named: listVM.placeList.name)?.addPlace(place)
                            }
                        }) {
                            HStack {
                                // Display the list’s image if available:
                                if let listImage = listVM.getImage() {
                                    Image(uiImage: listImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 75, height: 75)
                                        .clipped()
                                        .cornerRadius(4)
                                } else {
                                    // Fallback placeholder
                                    Rectangle()
                                        .frame(width: 75, height: 75)
                                        .foregroundColor(.white)
                                        .cornerRadius(4)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(listVM.placeList.name)
                                        .font(.body)
                                        .foregroundStyle(.white)

                                    Text("\(listVM.placeList.places.count) Places")
                                        .font(.caption)
                                        .foregroundStyle(.white)
                                }
                                .padding(.horizontal, 15)
                                
                                Spacer()
                                
                                // Circle to indicate selection
                                ZStack {
                                    Circle()
                                        .stroke(Color.white)
                                        .frame(width: 24, height: 24)
                                    if selectedListIds.contains(listVM.placeList.id) {
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 18, height: 18)
                                    }
                                }
                            }
                            .padding(.top, 20)
                            .padding(.horizontal, 15)
                        }
                    }
                }
            } else {
                Text("No lists available")
                    .foregroundColor(.gray)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .padding()
    }
}
