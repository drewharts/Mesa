//
//  TripPlaceSourceView.swift
//  loc
//
//  Bottom half of trip detail: browse saved places (lists or map) with push/pop transitions
//

import SwiftUI

/// Navigation destinations for the trip place source browser.
enum TripSourceDestination: Hashable {
    case listPlaces(listId: String)
    case placeDetail(placeId: String)
}

/// Container for browsing saved places (lists or map) and dragging them to calendar days.
struct TripPlaceSourceView: View {
    @EnvironmentObject var userSession: UserSession
    @ObservedObject var tripViewModel: TripDetailViewModel
    @StateObject private var listVM = TripAddPlaceToItineraryViewModel()
    @StateObject private var mapVM = TripMapPlacePickerViewModel()

    @State private var showingMap = false
    @State private var searchText = ""
    @State private var placeColors: [UUID: Color] = [:]
    @State private var screenStack: [TripSourceDestination] = []
    @State private var navigationDirection: Edge = .trailing

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            tripSourceNavigationBar
            ZStack {
                if let current = screenStack.last {
                    destinationView(for: current)
                        .id(current)
                        .transition(.push(from: navigationDirection))
                } else {
                    rootContent
                        .transition(.push(from: navigationDirection))
                }
            }
            .clipped()
            .animation(.easeInOut(duration: 0.35), value: screenStack)
        }
        .task {
            if let userId = userSession.currentUserId {
                mapVM.alreadyAddedPlaceIds = tripViewModel.allPlaceIdsInTrip
                await withTaskGroup(of: Void.self) { group in
                    group.addTask { await listVM.loadUserLists(userId: userId) }
                    group.addTask { await mapVM.loadAllUserPlaces(userId: userId) }
                }
            }
        }
    }

    // MARK: - Navigation

    /// Pushes a new destination onto the manual screen stack with a trailing transition.
    private func pushScreen(_ destination: TripSourceDestination) {
        navigationDirection = .trailing
        screenStack.append(destination)
    }

    /// Pops the top destination off the screen stack with a leading transition.
    private func popScreen() {
        navigationDirection = .leading
        let popped = screenStack.removeLast()
        if case .listPlaces = popped {
            listVM.clearPlaces()
        }
    }

    /// Routes a navigation destination to its corresponding view.
    @ViewBuilder
    private func destinationView(for destination: TripSourceDestination) -> some View {
        switch destination {
        case .listPlaces(let listId):
            listPlacesContent(listId: listId)
        case .placeDetail(let placeId):
            TripPlaceDetailView(placeId: placeId)
        }
    }

    // MARK: - Root Content

    /// Root content showing either the lists grid or the map.
    @ViewBuilder
    private var rootContent: some View {
        if showingMap {
            TripPlaceSourceMapContentView(
                mapVM: mapVM,
                alreadyAddedIds: tripViewModel.allPlaceIdsInTrip,
                onPlaceTap: { placeId in
                    pushScreen(.placeDetail(placeId: placeId))
                }
            )
        } else {
            listsTabContent
        }
    }

    // MARK: - Navigation Bar

    /// Combined search field, back button, and map toggle bar.
    private var tripSourceNavigationBar: some View {
        HStack(spacing: 16) {
            if !screenStack.isEmpty {
                navBackButton
            }
            searchCapsule
            mapToggleButton
        }
        .animation(.easeInOut(duration: 0.2), value: screenStack.count)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    /// Circular back button matching the map toggle style.
    private var navBackButton: some View {
        Button { popScreen() } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 36, height: 36)
                .background(Color(.systemGray5).opacity(0.6))
                .clipShape(Circle())
        }
    }

    /// Inline search capsule with a TextField for filtering lists.
    private var searchCapsule: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextField("Search places...", text: $searchText)
                .font(.subheadline)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray5).opacity(0.6))
        .clipShape(Capsule())
    }

    /// Circular button to toggle between lists and map views.
    private var mapToggleButton: some View {
        Button {
            screenStack.removeAll()
            listVM.clearPlaces()
            showingMap.toggle()
        } label: {
            Image(systemName: showingMap ? "list.bullet" : "map")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 36, height: 36)
                .background(Color(.systemGray5).opacity(0.6))
                .clipShape(Circle())
        }
    }

    // MARK: - Lists Tab

    /// Shows loading indicator or the lists grid.
    @ViewBuilder
    private var listsTabContent: some View {
        if listVM.isLoadingLists {
            ProgressView("Loading your lists...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            listsGridView
        }
    }

    /// Content for a selected list showing its places in a grid.
    @ViewBuilder
    private func listPlacesContent(listId: String) -> some View {
        let places = listVM.listPlaces[listId] ?? []
        if listVM.isLoadingPlacesForList {
            ProgressView("Loading places...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if places.isEmpty {
            Text("No places in this list")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(places) { place in
                        let isAdded = tripViewModel.allPlaceIdsInTrip.contains(place.place_id)
                        TripSelectablePlaceCard(
                            place: place,
                            isSelected: isAdded,
                            onToggle: {},
                            onDetailTap: {
                                pushScreen(.placeDetail(placeId: place.place_id))
                            }
                        )
                        .draggable(place.place_id) {
                            TripPlaceDragPreview(placeName: place.name)
                        }
                        .overlay(alignment: .topTrailing) {
                            if isAdded {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.title3)
                                    .background(Circle().fill(.white).padding(2))
                                    .padding(6)
                            }
                        }
                    }
                }
                .padding()
            }
        }
    }

    /// User lists filtered by the current search text.
    private var filteredLists: [LightweightPlaceList] {
        if searchText.isEmpty {
            return listVM.userLists
        }
        return listVM.userLists.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// Grid of the user's saved lists.
    private var listsGridView: some View {
        Group {
            if listVM.userLists.isEmpty {
                Text("No saved lists")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    if filteredLists.isEmpty {
                        Text("No matching lists")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(Array(filteredLists.enumerated()), id: \.element.id) { index, list in
                                    LightweightProfileListSection(
                                        list: list,
                                        places: listVM.listPlaces[list.list_id] ?? [],
                                        allLists: filteredLists,
                                        currentIndex: index,
                                        placeColors: $placeColors,
                                        onTap: {
                                            pushScreen(.listPlaces(listId: list.list_id))
                                            Task {
                                                await listVM.loadAllPlacesForList(listId: list.list_id)
                                            }
                                        }
                                    )
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
        }
    }
}
