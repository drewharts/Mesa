//
//  ListSelectionSheet.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/25/24.
//

import SwiftUI
import GooglePlaces

struct ListDescription: View {
    @EnvironmentObject var profile: ProfileViewModel
    let placeList: PlaceList
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(placeList.name)
                .font(.body)
                .foregroundStyle(.white)
            
            Text("\(profile.placeListGMSPlaces[placeList.id]?.count ?? 0) Places")                .font(.caption)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 15)

    }
}
struct ListsInSelectionSheet: View {
    @EnvironmentObject var profile: ProfileViewModel
    let place: GMSPlace

    var body: some View {
        ScrollView {
            if !profile.userLists.isEmpty {
                ForEach(profile.userLists) { list in
                    Button(action: {
                        // Determine whether the current list already contains the place.
                        let isAdded = profile.isPlaceInList(listId: list.id, placeId: place.placeID!)
                        
                        if isAdded {
                            // Remove the place from the list.
                            profile.removePlaceFromList(listId: list.id, place: place)
                        } else {
                            // Add the place to the list.
                            profile.addPlaceToList(listId: list.id, place: place)
                        }
                    }) {
                        HStack {
                            // Display the list’s image if available.
                            if let listImage = profile.listImages[list.id] {
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
                            
                            ListDescription(placeList: list)
                            
                            Spacer()
                            
                            // Use the computed 'isAdded' flag to decide the bubble appearance.
                            ZStack {
                                if profile.placeListGMSPlaces[list.id]?.contains(where: { $0.placeID == place.placeID }) ?? false {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 24, height: 24)
                                } else {
                                    Circle()
                                        .stroke(Color.white)
                                        .frame(width: 24, height: 24)
                                }
                            }
                        }
                        .padding(.top, 20)
                        .padding(.horizontal, 15)
                    }
                }
            } else {
                Text("No lists available")
                    .foregroundColor(.gray)
                    .padding(.horizontal)
            }
        }
    }
}

struct ListSelectionSheet: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var lists: PlaceListViewModel
    let place: GMSPlace
    @Binding var isPresented: Bool
    @State private var showNewListSheet = false
    @State private var newListName = ""
    @State public var searchText = ""

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
                .sheet(isPresented: $showNewListSheet) {
                    NewListView(isPresented: $showNewListSheet, onSave: { listName in
                        profile.addNewPlaceList(named: listName, city: "", emoji: "", image: "")
                    })
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            SkinnySearchBar()
            
            ListsInSelectionSheet(place: place)

            Spacer()
        }
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .padding()
    }
}
