//
//  ExploreDestination.swift
//  loc
//
//  Navigation destinations pushed inside the Explore tab's NavigationStack.
//

import Foundation

/// Screens the Explore tab can push. Lists are not pushed: they open in the Map tab's list sheet.
enum ExploreDestination: Hashable {
    case city(ExploreCity)
}
