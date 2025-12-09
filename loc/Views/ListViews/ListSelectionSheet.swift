//
//  ListSelectionSheet.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/25/24.
//

import SwiftUI
import CoreLocation

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
// DUMB Component: Displays list name and place count (or shared info)
struct LightweightListDescription: View {
    @EnvironmentObject var profile: ProfileViewModel
    let list: LightweightPlaceList

    // Get total place count from the list (from SQL function)
    private var displayedPlaceCount: Int {
        return profile.lightweightPlaceListCounts[list.list_id] ?? list.place_count
    }
    
    private var ownerFirstName: String? {
        list.owner_name?.components(separatedBy: " ").first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(list.name)
                .font(.body)
                .foregroundStyle(Color.primary.opacity(1.0))

            // Show different subtitle for shared vs owned lists
            if list.isSharedWithMe, let ownerName = ownerFirstName {
                HStack(spacing: 4) {
                    Text("\(displayedPlaceCount) Places")
                    Text("•")
                        .foregroundStyle(Color.secondary.opacity(0.5))
                    Text("Shared by \(ownerName)")
                }
                .font(.caption)
                .foregroundStyle(Color.secondary.opacity(1.0))
            } else {
                Text("\(displayedPlaceCount) Places")
                    .font(.caption)
                    .foregroundStyle(Color.secondary.opacity(1.0))
            }
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
// Refactored to be a dumb view that delegates behavior via closures.
struct LightweightListSelectionRowView: View {
    let list: LightweightPlaceList
    let place: DetailPlace
    let isInList: Bool
    let onToggle: () -> Void
    @State private var backgroundColor: Color = Color(.systemGray5)

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
        onToggle()
    }
}

// MARK: - ListsInSelectionSheet (Lightweight - uses place coordinates!)
struct ListsInSelectionSheet: View {
    @ObservedObject var viewModel: PlaceListSelectionViewModel
    let place: DetailPlace

    var isLoading: Bool {
        viewModel.isLoadingInitial
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
            } else if !viewModel.lists.isEmpty {
                ForEach(Array(viewModel.lists.enumerated()), id: \.element.id) { index, list in
                    LightweightListSelectionRowView(
                        list: list,
                        place: place,
                        isInList: viewModel.isPlace(place, in: list),
                        onToggle: {
                            viewModel.toggle(place: place, in: list)
                        }
                    )
                        .onAppear {
                            // ViewModel handles the logic of when to load more
                            Task {
                                await viewModel.loadMoreListsIfNeeded(currentIndex: index)
                            }
                        }
                }
                
                // Loading indicator at the bottom
                if viewModel.isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Text("No lists available")
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                }
            }
        }
    }
}

// MARK: - ListSelectionSheet
struct ListSelectionSheet: View {
    @ObservedObject var viewModel: PlaceListSelectionViewModel
    let place: DetailPlace
    @Binding var isPresented: Bool
    @State private var showNewListSheet = false
    @State private var errorMessage: String?
    @State private var showError = false

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
                        let result = await viewModel.addNewListToSelection(
                            named: listName, 
                            city: "", 
                            emoji: "", 
                            image: ""
                        )
                        
                        // Handle result explicitly
                        switch result {
                        case .success:
                            break  // Sheet will dismiss via NewListView
                        case .failure(let error):
                            errorMessage = error.localizedDescription
                            showError = true
                        }
                    })
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)

            ListsInSelectionSheet(viewModel: viewModel, place: place)

            Spacer()
        }
        .cornerRadius(20)
        .padding()
        .task {
            await viewModel.loadInitialLists(for: place)
        }
        .alert("Error Creating List", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Unknown error occurred")
        }
    }
}
