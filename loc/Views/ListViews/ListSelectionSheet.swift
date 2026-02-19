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

            Text("\(profile.listsViewModel.placeCount(forListId: placeList.id)) Places")
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
    @ObservedObject var listsVM: ProfileListsViewModel
    let list: LightweightPlaceList

    // Get total place count from the list (from SQL function)
    private var displayedPlaceCount: Int {
        return listsVM.lightweightPlaceListCounts[list.list_id] ?? list.place_count
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
    @ObservedObject var listsVM: ProfileListsViewModel
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
                    if listsVM.userListsPlaces[list.id.uuidString]?.contains(place.id.uuidString) ?? false {
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
    @ObservedObject var listsVM: ProfileListsViewModel

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // List info on the left
                LightweightListDescription(listsVM: listsVM, list: list)

                Spacer()

                // Collaborator avatars for ANY collaborative list (shared with you OR you shared)
                if list.isCollaborative {
                    InlineCollaboratorAvatars(
                        isOwnedByMe: !list.isSharedWithMe,
                        ownerPhotoUrl: list.owner_photo_url,
                        ownerName: list.owner_name,
                        collaboratorPhotos: list.collaborator_photos
                    )
                }

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
                            .fill(Color.primary)
                    .frame(width: 20, height: 20)
                    } else {
                        Circle()
                    .stroke(Color.primary, lineWidth: 1.5)
                    .frame(width: 20, height: 20)
                    }
                }
            }
}

// MARK: - Inline Collaborator Avatars
// DUMB Component: Compact avatar stack for inline display in list rows
// Uses CachedProfileImage for proper caching and loading states
private struct InlineCollaboratorAvatars: View {
    let isOwnedByMe: Bool        // If true, don't show owner avatar (you ARE the owner)
    let ownerPhotoUrl: String?
    let ownerName: String?
    let collaboratorPhotos: [String]?
    
    private let avatarSize: CGFloat = 24
    
    /// How many collaborator avatars to show (more if we're not showing owner)
    private var maxCollaboratorAvatars: Int {
        isOwnedByMe ? 3 : 2
    }
    
    var body: some View {
        HStack(spacing: -8) {
            // Owner avatar (only for lists shared WITH you)
            if !isOwnedByMe {
                CachedProfileImage(
                    url: ownerPhotoUrl,
                    size: avatarSize,
                    fallbackInitial: String(ownerName?.prefix(1).uppercased() ?? "?")
                )
                .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
        }
            
            // Collaborator avatars
            if let photos = collaboratorPhotos {
                ForEach(Array(photos.prefix(maxCollaboratorAvatars).enumerated()), id: \.offset) { index, photoUrl in
                    CachedProfileImage(
                        url: photoUrl,
                        size: avatarSize,
                        fallbackInitial: "?"
                    )
                    .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                    .zIndex(Double(-index - 1))
                }
                
                // Overflow badge
                if photos.count > maxCollaboratorAvatars {
                    overflowBadge(count: photos.count - maxCollaboratorAvatars)
                        .zIndex(-4)
                }
            }
        }
    }
    
    private func overflowBadge(count: Int) -> some View {
        Circle()
            .fill(Color.gray.opacity(0.6))
            .frame(width: avatarSize, height: avatarSize)
            .overlay(
                Text("+\(count)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
            )
            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
    }
}

// MARK: - ListsInSelectionSheet (Lightweight - uses place coordinates!)
// DUMB Component: Displays scrollable list of lists for selection
struct ListsInSelectionSheet: View {
    @ObservedObject var viewModel: PlaceListSelectionViewModel
    let place: DetailPlace
    @ObservedObject var listsVM: ProfileListsViewModel

    var body: some View {
        ScrollView {
            if viewModel.isLoadingInitial {
                loadingView
            } else {
                LazyVStack(spacing: 0) {
                    // Favorites row always visible regardless of list count
                    FavoritesSelectionRow(
                        isFavorited: viewModel.isFavorited,
                        onToggle: {
                            viewModel.toggleFavorite(place: place)
                        }
                    )

                    Divider()
                        .padding(.horizontal, 16)

                    if !viewModel.filteredLists.isEmpty {
                        listContent
                    } else {
                        emptyStateView
                    }
                }
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
        Group {
            ForEach(Array(viewModel.filteredLists.enumerated()), id: \.element.id) { index, list in
                LightweightListSelectionRowView(
                    list: list,
                    place: place,
                    isInList: viewModel.isPlace(place, in: list),
                    onToggle: {
                        viewModel.toggle(place: place, in: list)
                    },
                    listsVM: listsVM
                )
                .onAppear {
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
        }
        // Force complete rebuild when filter changes to fix LazyVStack layout issues
        .id(viewModel.showOnlyShared)
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
                Text("Create a list with the + button")
                    .font(.subheadline)
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
    @ObservedObject var listsVM: ProfileListsViewModel
    @Binding var isPresented: Bool
    @State private var showNewListSheet = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with integrated filter
            sheetHeader
            
            // Breathing room
                Spacer()
                .frame(height: 16)
            
            // List content
            ListsInSelectionSheet(viewModel: viewModel, place: place, listsVM: listsVM)
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
        VStack(spacing: 0) {
            // Drag indicator
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.gray.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 16)
            
            // Title and buttons row - ZStack for true centering
            ZStack {
                // Centered title
                Text("Save to list")
                    .font(.headline)
                
                // Buttons on sides
                HStack {
                    // Shared filter on left (only if there are shared lists)
                    if viewModel.hasSharedLists {
                        sharedFilterButton
                    }

                Spacer()

                Button(action: {
                    showNewListSheet = true
                }) {
                    Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color(.systemGray5)))
                }
                .sheet(isPresented: $showNewListSheet) {
                    NewListSheetView(onSave: { listName in
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
                    .presentationDetents([.height(200)])
                    .presentationDragIndicator(.visible)
                }
                }
            }
            .padding(.horizontal, 20)
            
            // Search bar
            searchBar
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .font(.system(size: 14))
            
            TextField("Search lists...", text: $viewModel.searchText)
                .font(.subheadline)
            
            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 14))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
    
    // MARK: - Shared Filter Button
    
    private var sharedFilterButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.showOnlyShared.toggle()
        }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 10))
                Text("Shared")
                    .font(.subheadline)
        }
            .foregroundColor(viewModel.showOnlyShared ? .white : .primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(viewModel.showOnlyShared ? Color.primary : Color(.systemGray5))
            )
        }
    }
    
}
