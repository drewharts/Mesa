//
//  MapAnnotationItem.swift
//  loc
//
//  Unified GMUClusterItem wrapper bridging the app's four independent map pin
//  models (city, community, network/friend, trip) into Google Maps SDK's
//  GMUClusterManager annotation/clustering system.
//

import CoreLocation
import GoogleMapsUtils

/// Identifies which source model a MapAnnotationItem wraps, and carries the underlying data.
enum MapAnnotationLayer {
    case city(CityAnnotation)
    case community(CommunityPlaceMarker)
    case network(PlaceAnnotation)
    case trip(TripMapAnnotation)
    case userLocation
}

/// Reference-type GMUClusterItem unifying city/community/network/trip pins and the user
/// location dot. Reference identity (not structural equality) is required for our own
/// add/remove diffing, so this intentionally does NOT override isEqual/hash.
final class MapAnnotationItem: NSObject, GMUClusterItem {
    /// Stable diffing key, e.g. "network_<id>". Used only by our own add/remove diffing.
    let stableId: String
    let layer: MapAnnotationLayer

    var coordinate: CLLocationCoordinate2D
    var title: String?

    /// GMUClusterItem's required position — an alias for coordinate, since GMUClusterManager
    /// (not MapKit) is what now reads this to place and cluster the item.
    var position: CLLocationCoordinate2D { coordinate }

    /// The underlying place identifier used for tap-routing, regardless of layer.
    var placeId: String? {
        switch layer {
        case .city(let city): return city.id
        case .community(let marker): return marker.id
        case .network(let annotation): return annotation.id
        case .trip(let trip): return trip.placeId
        case .userLocation: return nil
        }
    }

    init(city: CityAnnotation) {
        self.stableId = "city_\(city.id)"
        self.layer = .city(city)
        self.coordinate = city.coordinate
        self.title = city.name
    }

    init(community: CommunityPlaceMarker) {
        self.stableId = "community_\(community.id)"
        self.layer = .community(community)
        self.coordinate = community.coordinate
        self.title = community.name
    }

    init(network: PlaceAnnotation) {
        self.stableId = "network_\(network.id)"
        self.layer = .network(network)
        self.coordinate = network.coordinate
        self.title = network.name
    }

    init(trip: TripMapAnnotation) {
        self.stableId = "trip_\(trip.id)"
        self.layer = .trip(trip)
        self.coordinate = trip.coordinate
        self.title = trip.placeName
    }

    init(userLocation coordinate: CLLocationCoordinate2D) {
        self.stableId = "user_location"
        self.layer = .userLocation
        self.coordinate = coordinate
        self.title = nil
    }
}
