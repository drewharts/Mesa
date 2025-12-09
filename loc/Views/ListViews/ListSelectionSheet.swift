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
// DUMB Component: Displays a list row for selection, delegates toggle via closure
struct LightweightListSelectionRowView: View {
    let list: LightweightPlaceList
    let place: DetailPlace
    let isInList: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Thumbnail: avatars for shared lists, empty for owned
                ListRowThumbnail(
                    isShared: list.isSharedWithMe,
                    ownerPhotoUrl: list.owner_photo_url,
                    ownerName: list.owner_name,
                    collaboratorPhotos: list.collaborator_photos
                )

                LightweightListDescription(list: list)

                Spacer()

                // Selection indicator
                selectionIndicator
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var selectionIndicator: some View {
        ZStack {
            if isInList {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    )
            } else {
                Circle()
                    .stroke(Color.gray.opacity(0.4), lineWidth: 2)
                    .frame(width: 24, height: 24)
            }
        }
    }
}

// MARK: - ListsInSelectionSheet (Lightweight - uses place coordinates!)
// DUMB Component: Displays scrollable list of lists for selection
struct ListsInSelectionSheet: View {
    @ObservedObject var viewModel: PlaceListSelectionViewModel
    let place: DetailPlace

    var body: some View {
        ScrollView {
            if viewModel.isLoadingInitial {
                loadingView
            } else if !viewModel.filteredLists.isEmpty {
                listContent
            } else {
                emptyStateView
            }
        }
    }
    
    // MARK: - Subviews
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .frame(width: 20, height: 20)
            Text("Loading your lists...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    private var listContent: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(viewModel.filteredLists.enumerated()), id: \.element.id) { index, list in
                VStack(spacing: 0) {
                    LightweightListSelectionRowView(
                        list: list,
                        place: place,
                        isInList: viewModel.isPlace(place, in: list),
                        onToggle: {
                            viewModel.toggle(place: place, in: list)
                        }
                    )
                    .onAppear {
                        Task {
                            await viewModel.loadMoreListsIfNeeded(currentIndex: index)
                        }
                    }
                    
                    // Divider between rows
                    if index < viewModel.filteredLists.count - 1 {
                        Divider()
                            .padding(.leading, 88) // Align with text, past thumbnail
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
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            if viewModel.showOnlyShared {
                Image(systemName: "person.2")
                    .font(.system(size: 32))
                    .foregroundColor(.gray.opacity(0.5))
                Text("No shared lists")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Text("Lists shared with you will appear here")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.7))
            } else {
                Text("No lists available")
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 40)
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
        VStack(spacing: 0) {
            // Header
            sheetHeader
            
            Divider()
            
            // Filter bar (only show if there are shared lists)
            if viewModel.hasSharedLists {
                filterBar
                Divider()
            }
            
            // List content
            ListsInSelectionSheet(viewModel: viewModel, place: place)
        }
        .task {
            await viewModel.loadInitialLists(for: place)
        }
        .alert("Error Creating List", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Unknown error occurred")
        }
    }
    
    // MARK: - Header
    
    private var sheetHeader: some View {
        HStack {
            // Spacer for balance
            Color.clear
                .frame(width: 32, height: 32)
            
            Spacer()

            Text("Save to list")
                .font(.headline)

            Spacer()

            Button(action: {
                showNewListSheet = true
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.blue)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.blue.opacity(0.1)))
            }
            .sheet(isPresented: $showNewListSheet) {
                NewListView(isPresented: $showNewListSheet, onSave: { listName in
                    let result = await viewModel.addNewListToSelection(
                        named: listName, 
                        city: "", 
                        emoji: "", 
                        image: ""
                    )
                    
                    switch result {
                    case .success:
                        break
                    case .failure(let error):
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                })
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    // MARK: - Filter Bar
    
    private var filterBar: some View {
        HStack {
            Text("Filter")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Shared lists filter toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.showOnlyShared.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 12))
                    Text("Shared (\(viewModel.sharedListCount))")
                        .font(.subheadline)
                }
                .foregroundColor(viewModel.showOnlyShared ? .white : .blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(viewModel.showOnlyShared ? Color.blue : Color.blue.opacity(0.1))
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color(.systemGray6).opacity(0.5))
    }
}
