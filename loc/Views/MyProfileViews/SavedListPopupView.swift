//
//  SavedListPopupView.swift
//  loc
//
//  Popup view for viewing a saved list's places.
//  Reuses the same place navigation pattern as other list popups.
//

import SwiftUI

/// Displays a saved list's places in a scrollable popup.
struct SavedListPopupView: View {
    let list: LightweightPlaceList
    let places: [LightweightPlace]
    @Binding var placeColors: [UUID: Color]

    @EnvironmentObject var profile: ProfileViewModel
    @Environment(\.presentationMode) var presentationMode

    /// Observed for pending place navigation when map annotation is tapped while sheet is open.
    @ObservedObject private var presentationService = PresentationService.shared

    @State private var navigationPath = NavigationPath()
    @State private var hasInitiallyAppeared = false

    private let listColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                popupHeader
                popupContent
            }
            .navigationBarHidden(true)
            .navigationDestination(for: String.self) { placeId in
                PlaceDetailViewInNavigation(placeId: placeId, minSheetHeight: 250, shouldAnimateMap: true)
                    .id(placeId)
            }
        }
        .onReceive(presentationService.$pendingPlaceNavigation.compactMap { $0 }) { placeId in
            // When map annotation is tapped while saved list sheet is open, navigate to that place.
            var newPath = NavigationPath()
            newPath.append(placeId)
            navigationPath = newPath
            presentationService.pendingPlaceNavigation = nil
        }
        .onAppear {
            guard !hasInitiallyAppeared else { return }
            hasInitiallyAppeared = true
            navigationPath = NavigationPath()
        }
    }

    // MARK: - Popup Header

    private var popupHeader: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(list.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    if let ownerName = list.owner_name {
                        Text("by \(ownerName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text("\(list.place_count) place\(list.place_count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                unsaveButton
                dismissButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .padding(.bottom, 16)
    }

    private var dismissButton: some View {
        Button(action: { presentationMode.wrappedValue.dismiss() }) {
            Image(systemName: "xmark")
                .font(.system(size: 20, weight: .regular))
                .foregroundColor(.primary)
        }
        .frame(width: 44, height: 44)
    }

    private var unsaveButton: some View {
        Button(action: {
            Task {
                _ = await profile.savedListsViewModel.unsaveList(listId: list.list_id)
                presentationMode.wrappedValue.dismiss()
            }
        }) {
            Image(systemName: "bookmark.slash")
                .font(.system(size: 20, weight: .regular))
                .foregroundColor(.primary)
        }
        .frame(width: 44, height: 44)
    }

    // MARK: - Popup Content

    private var popupContent: some View {
        ScrollView {
            if places.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: listColumns, spacing: 12) {
                    ForEach(places, id: \.id) { place in
                        PopupPlaceCard(
                            place: place,
                            preferExternalThumbnail: true,
                            onNavigate: { placeId in
                                navigationPath.append(placeId)
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 32))
                .foregroundColor(.tertiary)
            Text("No places in this list")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
