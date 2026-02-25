//
//  TripMapAnnotation.swift
//  loc
//
//  Display-ready annotation for trip map pins
//

import SwiftUI
import CoreLocation

/// A display-ready map annotation representing a place on a specific trip day.
struct TripMapAnnotation: Identifiable, Equatable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let placeName: String
    let placeAddress: String?
    let dayIndex: Int
    let stopNumber: Int
    let totalStopsInDay: Int
    let color: Color
    let placeId: String
    let placeType: String?

    static func == (lhs: TripMapAnnotation, rhs: TripMapAnnotation) -> Bool {
        lhs.id == rhs.id
            && lhs.dayIndex == rhs.dayIndex
            && lhs.stopNumber == rhs.stopNumber
            && lhs.totalStopsInDay == rhs.totalStopsInDay
            && lhs.placeId == rhs.placeId
    }
}
