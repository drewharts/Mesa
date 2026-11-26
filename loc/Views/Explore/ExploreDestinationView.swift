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
    /// Publishes this destination's header to the sheet's strip.
    let onHeader: (TabSheetHeader) -> Void
    let onBack: () -> Void

    var body: some View {
        screen.toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private var screen: some View {
        switch destination {
        case .city(let city):
            ExploreCityListsView(city: city, onListTap: onListTap)
                .onAppear { onHeader(TabSheetHeader(id: "city-\(city.id)", title: city.name, creator: nil, detail: nil, onBack: onBack, onShare: nil)) }
        case .list(let list, _):
            ExploreListDetailView(list: list, onOpenPlace: onPlaceTap, onOpenProfile: onUserTap, onHeader: onHeader, onBack: onBack)
        case .place(let placeId):
            ExplorePlaceDestinationView(placeId: placeId, onHeader: onHeader, onBack: onBack)
                .id(placeId)
        case .user(let profile):
            ExternalUserProfileViewWrapper(user: profile)
                .onAppear { onHeader(TabSheetHeader(id: "user-\(profile.id)", title: profile.fullName, creator: nil, detail: nil, onBack: onBack, onShare: nil)) }
        }
    }
}
