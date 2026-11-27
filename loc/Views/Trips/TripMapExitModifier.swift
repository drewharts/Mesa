//
//  TripMapExitModifier.swift
//  loc
//
//  Clears trips from the main map when they leave the Trips tab navigation stack.
//

import SwiftUI

/// Clears trip pins and routes from the map when trips are popped or the Trips tab is hidden, and re-arms the open trip when the tab returns.
struct TripMapExitModifier: ViewModifier {
    let path: [String]
    let isActive: Bool
    let coordinator: MapDisplayCoordinatorViewModel
    let viewModel: TripsListViewModel

    func body(content: Content) -> some View {
        content
            .onChange(of: path) { old, new in
                viewModel.clearTripsRemoved(from: old, to: new, on: coordinator)
            }
            .onChange(of: isActive) { _, active in
                if active {
                    viewModel.beginTripSession(path.last, on: coordinator)
                } else {
                    viewModel.clearTrips(path, on: coordinator)
                }
            }
    }
}
