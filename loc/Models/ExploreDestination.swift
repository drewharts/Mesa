//
//  ExploreDestination.swift
//  loc
//
//  Navigation destinations pushed inside the Explore tab's NavigationStack.
//

import Foundation

/// Screens the Explore tab can push; everything opened from Explore stays in the sheet's own stack.
enum ExploreDestination: Hashable {
    case city(ExploreCity)
    /// A list's places (pins shown on the map); `startFindTable` also opens its "Find a table" form.
    case list(ExploreList, startFindTable: Bool)
    /// A place's detail page, by place id.
    case place(String)
    /// Another user's profile.
    case user(ProfileData)
}
