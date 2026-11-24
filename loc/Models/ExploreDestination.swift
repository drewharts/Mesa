//
//  ExploreDestination.swift
//  loc
//
//  Navigation destinations pushed inside the Explore tab's NavigationStack.
//

import Foundation

/// Screens the Explore tab can push.
enum ExploreDestination: Hashable {
    case city(ExploreCity)
    case list(ExploreList)
}
