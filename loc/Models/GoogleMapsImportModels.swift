//
//  GoogleMapsImportModels.swift
//  loc
//
//  Created by Claude on 2/9/26.
//

import Foundation
import CoreLocation

/// A raw place extracted from a Google Maps shared list page.
struct GoogleMapsImportPlace: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D?
    let address: String?
}

/// The resolution status of an imported place during the matching process.
enum PlaceResolutionStatus: Equatable {
    case pending
    case resolving
    case matched(DetailPlace)
    case failed(String)

    static func == (lhs: PlaceResolutionStatus, rhs: PlaceResolutionStatus) -> Bool {
        switch (lhs, rhs) {
        case (.pending, .pending), (.resolving, .resolving):
            return true
        case (.matched(let a), .matched(let b)):
            return a.id == b.id
        case (.failed(let a), .failed(let b)):
            return a == b
        default:
            return false
        }
    }
}

/// Wraps a raw imported place with its resolution status and selection state.
struct ResolvedImportPlace: Identifiable {
    let id: UUID
    let originalPlace: GoogleMapsImportPlace
    var status: PlaceResolutionStatus
    var isSelected: Bool = true
}

/// Summary of a completed batch import operation.
struct ImportSummary {
    let imported: Int
    let failed: Int
    let skipped: Int
}

/// Phases of the Google Maps import flow.
enum GoogleMapsImportPhase: Equatable {
    case input
    case extracting
    case resolving
    case review
    case importing
    case complete
}
