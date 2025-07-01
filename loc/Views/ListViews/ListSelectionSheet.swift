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
                .foregroundStyle(Color.primary.opacity(1.0)) // Ensures black in light mode, white in dark mode

            Text("\(profile.placeCount(forListId: placeList.id)) Places")
                .font(.caption)
                .foregroundStyle(Color.secondary.opacity(1.0)) // Slightly lighter, adapts to mode
        }
        .padding(.horizontal, 15)
    }
}

// ListSelectionRowView
struct ListSelectionRowView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    let list: PlaceList
    let place: DetailPlace
    @State private var backgroundColor: Color = Color(.systemGray5)

    var body: some View {
        Button(action: {
            togglePlaceInList()
        }) {
            HStack {
                // Display list image, place image, or colored rectangle
                Group {
                    Rectangle()
                        .foregroundColor(backgroundColor)
                        .onAppear {
                            backgroundColor = Color(
                                red: Double.random(in: 0.5...0.9),
                                green: Double.random(in: 0.5...0.9),
                                blue: Double.random(in: 0.5...0.9)
                            )
                        }
                }
                .frame(width: 75, height: 75)
                .clipped()
                .cornerRadius(4)

                ListDescription(placeList: list)

                Spacer()

                ZStack {
                    if profile.userListsPlaces[list.id.uuidString]?.contains(place.id.uuidString) ?? false {
                        Circle()
                            .fill(Color.primary)
                            .frame(width: 24, height: 24)
                    } else {
                        Circle()
                            .stroke(Color.primary, lineWidth: 2)
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
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    let place: DetailPlace
    @Binding var searchText: String
    
    // Filtered lists based on search text and sorted by proximity to the place
    var filteredLists: [PlaceList] {
        let sortedLists = profile.sortListsByDistanceFromPlace(place)
        
        if searchText.isEmpty {
            return sortedLists
        } else {
            return sortedLists.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        ScrollView {
            if !filteredLists.isEmpty {
                ForEach(filteredLists) { list in
                    ListSelectionRowView(list: list, place: place)
                }
            } else {
                VStack(spacing: 8) {
                    if searchText.isEmpty {
                        Text("No lists available")
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                    } else {
                        Text("No lists found")
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                        Text("No lists match '\(searchText)'")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                    }
                }
            }
        }
    }
}

// MARK: - ListSelectionSheet
struct ListSelectionSheet: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var lists: PlaceListViewModel
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
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
                        .foregroundColor(.gray)
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

            SkinnySearchBar(searchText: $searchText)

            ListsInSelectionSheet(place: place, searchText: $searchText)

            Spacer()
        }
        .cornerRadius(20)
        .padding()
    }
}
