//
//  ExploreDestinationView.swift
//  loc
//
//  Resolves an ExploreDestination to its screen.
//

import SwiftUI

/// Builds the pushed screen for a city page.
struct ExploreDestinationView: View {
    let destination: ExploreDestination
    let onListTap: (ExploreList) -> Void

    var body: some View {
        switch destination {
        case .city(let city):
            ExploreCityListsView(city: city, onListTap: onListTap)
        }
    }
}
