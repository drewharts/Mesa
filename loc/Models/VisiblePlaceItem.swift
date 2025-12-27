//
//  VisiblePlaceItem.swift
//  loc
//
//  Unified display model for places in the "Places in View" popup.
//  Abstracts both network places (friends) and community places into a single type.
//

import Foundation
import CoreLocation

/// Source type for visible places
enum VisiblePlaceSource {
    case friends    // Places from your network (you + people you follow)
    case community  // Places from the broader community (people you don't follow)
}

/// Unified model for displaying places in the visible places popup.
/// Abstracts both PlaceAnnotation (friends) and CommunityPlaceMarker (community).
struct VisiblePlaceItem: Identifiable {
    let id: String
    let name: String
    let coordinate: CLLocationCoordinate2D
    let source: VisiblePlaceSource
    
    // Friends-specific data
    let userIds: [String]?
    
    // Community-specific data
    let saveCount: Int?
    let placeType: String?
    let emoji: String?
    
    /// Create from a PlaceAnnotation (friends/network place)
    init(annotation: PlaceAnnotation) {
        self.id = annotation.id
        self.name = annotation.name
        self.coordinate = annotation.coordinate
        self.source = .friends
        self.userIds = annotation.userIds
        self.saveCount = nil
        self.placeType = nil
        self.emoji = nil
    }
    
    /// Create from a CommunityPlaceMarker (community place)
    init(marker: CommunityPlaceMarker) {
        self.id = marker.id
        self.name = marker.name
        self.coordinate = marker.coordinate
        self.source = .community
        self.userIds = nil
        self.saveCount = marker.saveCount
        self.placeType = marker.placeType
        self.emoji = marker.emoji
    }
}

// MARK: - Filter Type

/// Filter options for the visible places popup
enum VisiblePlacesFilter: String, CaseIterable, Identifiable {
    case friends = "Friends"
    case community = "Community"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .friends: return "person.2.fill"
        case .community: return "globe"
        }
    }
}

