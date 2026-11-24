//
//  ExploreDestinationView.swift
//  loc
//
//  Resolves an ExploreDestination to its screen. Lists reuse the existing list detail view.
//

import SwiftUI

/// Builds the pushed screen for a city page or a list.
struct ExploreDestinationView: View {
    let destination: ExploreDestination
    let onListTap: (ExploreList) -> Void
    let onOpenPlace: (String) -> Void
    let onOpenUser: (String) -> Void

    var body: some View {
        switch destination {
        case .city(let city):
            ExploreCityListsView(city: city, onListTap: onListTap)
        case .list(let list):
            CityListDetailView(
                listId: list.id,
                listName: list.name,
                creatorId: list.ownerId,
                creatorName: list.ownerName,
                creatorPhotoUrl: list.ownerPhotoURL,
                onPlaceTap: onOpenPlace,
                onCreatorTap: onOpenUser
            )
        }
    }
}
