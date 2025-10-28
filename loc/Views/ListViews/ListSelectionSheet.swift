//
//  ListSelectionSheet.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/25/24.
//

import SwiftUI

// ListDescription - OLD (for PlaceList)
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

// LightweightListDescription - NEW (for LightweightPlaceList)
struct LightweightListDescription: View {
    @EnvironmentObject var profile: ProfileViewModel
    let list: LightweightPlaceList

    // Computed property that reacts to changes in lightweightPlaceListPlaces
    private var currentPlaceCount: Int {
        profile.lightweightPlaceListPlaces[list.list_id]?.count ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(list.name)
                .font(.body)
                .foregroundStyle(Color.primary.opacity(1.0))

            Text("\(currentPlaceCount) Places")
                .font(.caption)
                .foregroundStyle(Color.secondary.opacity(1.0))
        }
        .padding(.horizontal, 15)
    }
}

// ListSelectionRowView - OLD (for PlaceList)
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

// LightweightListSelectionRowView - NEW (for LightweightPlaceList)
struct LightweightListSelectionRowView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var dataManager: DataManager
    let list: LightweightPlaceList
    let place: DetailPlace
    @State private var backgroundColor: Color = Color(.systemGray5)

    // Computed property that reacts to profile.lightweightPlaceListPlaces changes
    private var isInList: Bool {
        profile.lightweightPlaceListPlaces[list.list_id]?.contains(where: { $0.place_id == place.id.uuidString }) ?? false
    }

    var body: some View {
        Button(action: {
            togglePlaceInList()
        }) {
            HStack {
                // Display colored rectangle (or list image if available)
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

                LightweightListDescription(list: list)

                Spacer()

                ZStack {
                    if isInList {
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
        .buttonStyle(PlainButtonStyle())
    }
    
    private func togglePlaceInList() {
        Task {
            do {
                if isInList {
                    // Remove from list using ProfileViewModel's method
                    await MainActor.run {
                        profile.removePlaceFromLightweightList(listId: list.list_id, place: place)
                    }
                } else {
                    // Add to list using ProfileViewModel's method
                    await MainActor.run {
                        profile.addPlaceToLightweightList(listId: list.list_id, place: place)
                    }
                }
            } catch {
                print("❌ Error toggling place in list: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - ListsInSelectionSheet (Lightweight - uses place coordinates!)
struct ListsInSelectionSheet: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var userSession: UserSession
    let place: DetailPlace
    @Binding var searchText: String

    // Filtered lightweight lists based on search text (already sorted by proximity from SQL)
    var filteredLists: [LightweightPlaceList] {
        if searchText.isEmpty {
            return profile.lightweightPlaceLists
        } else {
            return profile.lightweightPlaceLists.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var isLoading: Bool {
        profile.lightweightPlaceLists.isEmpty && profile.isLoading
    }


    var body: some View {
        ScrollView {
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .frame(width: 20, height: 20)
                    Text("Loading your lists...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else if !filteredLists.isEmpty {
                ForEach(Array(filteredLists.enumerated()), id: \.element.id) { index, list in
                    LightweightListSelectionRowView(list: list, place: place)
                        .onAppear {
                            // Load more when we reach the 3rd-to-last item (same as ProfileView)
                            if index == filteredLists.count - 3 && searchText.isEmpty {
                                loadMoreListsIfNeeded()
                            }
                        }
                }
                
                // Loading indicator at the bottom
                if profile.isLoadingMorePlaceLists {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
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
        .onAppear {
            // Load lists by proximity to the place's coordinates
            if let userId = userSession.currentUserId,
               let coord = place.coordinate {
                Task {
                    await dataManager.loadPlaceListsByPlaceCoordinates(
                        userId: userId,
                        placeLatitude: coord.latitude,
                        placeLongitude: coord.longitude
                    )
                }
            }
        }
    }
    
    private func loadMoreListsIfNeeded() {
        guard !profile.isLoadingMorePlaceLists && profile.hasMorePlaceLists else { return }
        
        Task {
            await dataManager.loadMorePlaceLists(userId: userSession.currentUserId ?? "")
        }
    }
}

// MARK: - ListSelectionSheet
struct ListSelectionSheet: View {
    @EnvironmentObject var profile: ProfileViewModel
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
