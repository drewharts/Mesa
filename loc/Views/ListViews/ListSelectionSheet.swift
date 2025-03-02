//
//  ListSelectionSheet.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/25/24.
//

import SwiftUI
import MapboxSearch

// ListDescription
struct ListDescription: View {
    @EnvironmentObject var profile: ProfileViewModel
    let placeList: PlaceList

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(placeList.name)
                .font(.body)
                .foregroundStyle(.primary) // Adapts to light/dark mode
            
            Text("\(profile.placeListGMSPlaces[placeList.id]?.count ?? 0) Places")
                .font(.caption)
                .foregroundStyle(.secondary) // Slightly lighter for hierarchy
        }
        .padding(.horizontal, 15)
    }
}

// ListSelectionRowView
struct ListSelectionRowView: View {
    @EnvironmentObject var profile: ProfileViewModel
    let list: PlaceList
    let place: DetailPlace

    var body: some View {
        Button(action: {
            togglePlaceInList()
        }) {
            HStack {
                if let listImage = profile.listImages[list.id] {
                    Image(uiImage: listImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 75, height: 75)
                        .clipped()
                        .cornerRadius(4)
                } else {
                    Rectangle()
                        .frame(width: 75, height: 75)
                        .foregroundColor(.gray.opacity(0.2)) // Light gray placeholder
                        .cornerRadius(4)
                }

                ListDescription(placeList: list)

                Spacer()

                ZStack {
                    if profile.placeListGMSPlaces[list.id]?.contains(where: { $0.id == place.id }) ?? false {
                        Circle()
                            .fill(Color.accentColor) // Use accent color for visibility
                            .frame(width: 24, height: 24)
                    } else {
                        Circle()
                            .stroke(Color.primary, lineWidth: 2) // Adaptive outline
                            .frame(width: 24, height: 24)
                    }
                }
            }
            .padding(.top, 20)
            .padding(.horizontal, 15)
        }
    }

    private func togglePlaceInList() {
        let isAdded = profile.isPlaceInList(listId: list.id, placeId: place.id.uuidString)
        if isAdded {
            profile.removePlaceFromList(listId: list.id, place: place)
        } else {
            profile.addPlaceToList(listId: list.id, place: place)
        }
    }
}

// MARK: - ListsInSelectionSheet
struct ListsInSelectionSheet: View {
    @EnvironmentObject var profile: ProfileViewModel
    let place: DetailPlace

    var body: some View {
        ScrollView {
            if !profile.userLists.isEmpty {
                ForEach(profile.userLists) { list in
                    ListSelectionRowView(list: list, place: place)
                }
            } else {
                Text("No lists available")
                    .foregroundColor(.gray)
                    .padding(.horizontal)
            }
        }
    }
}

// MARK: - ListSelectionSheet
struct ListSelectionSheet: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var lists: PlaceListViewModel
    let place: DetailPlace
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
        .cornerRadius(20)
        .padding()
    }
}
