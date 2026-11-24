//
//  ExploreDestinationView.swift
//  loc
//
//  Resolves an ExploreDestination to its screen.
//

import SwiftUI

/// Builds the screen pushed onto the Explore sheet's stack.
struct ExploreDestinationView: View {
    let destination: ExploreDestination
    let onListTap: (ExploreList) -> Void
    let onPlaceTap: (String) -> Void
    let onUserTap: (ProfileData) -> Void

    var body: some View {
        switch destination {
        case .city(let city):
            ExploreCityListsView(city: city, onListTap: onListTap)
        case .list(let list, _):
            ExploreListDetailView(list: list, onOpenPlace: onPlaceTap, onOpenProfile: onUserTap)
        case .place(let placeId):
            PlaceDetailViewInNavigation(placeId: placeId, minSheetHeight: 250, shouldAnimateMap: true)
                .id(placeId)
        case .user(let profile):
            ExternalUserProfileViewWrapper(user: profile)
        }
    }
}
