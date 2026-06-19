//
//  ListActionsMenu.swift
//  loc
//
//  DUMB Component: Plus menu for creating lists, trips, and importing.
//  Reused by ProfileViewListsView and FullScreenListsView.
//

import SwiftUI

/// Plus button menu with list creation, trip creation, and import actions.
struct ListActionsMenu: View {
    let onAddList: () -> Void
    let onCreateTrip: () -> Void
    let onImportGoogleMaps: () -> Void

    var body: some View {
        Menu {
            Button { onAddList() } label: {
                Label("New List", systemImage: "plus")
            }
            Button { onCreateTrip() } label: {
                Label("New Trip", systemImage: "airplane")
            }
            Button { onImportGoogleMaps() } label: {
                Label("Import from Google Maps", systemImage: "map")
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Color(.systemGray6))
                )
        }
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Circle())
    }
}
