//
//  ImportJob.swift
//  loc
//
//  Models for asynchronous (live progress) external content imports.
//

import Foundation

/// Lifecycle status of a backend import job.
enum ImportJobStatus: String {
    case queued, downloading, transcribing, extracting, saving, done, failed

    /// Whether the job has finished (successfully or not).
    var isTerminal: Bool { self == .done || self == .failed }

    /// Human-readable status line shown while the import runs.
    var displayText: String {
        switch self {
        case .queued: return "Starting import…"
        case .downloading: return "Downloading video…"
        case .transcribing: return "Listening to the video…"
        case .extracting: return "Finding places…"
        case .saving: return "Adding places…"
        case .done: return "Import complete"
        case .failed: return "Import failed"
        }
    }
}

/// Status of a single place inside an import job.
enum ImportJobPlaceStatus: String {
    case found, saving, saved, duplicate, failed
}

/// One place detected by an import job.
struct ImportJobPlace: Identifiable {
    let index: Int
    let name: String
    let status: ImportJobPlaceStatus
    let placeId: String?
    let place: DetailPlace?

    var id: Int { index }
}

/// Snapshot of a backend import job.
struct ImportJob {
    let id: String
    let status: ImportJobStatus
    let totalFound: Int
    let places: [ImportJobPlace]
    let error: String?
    /// The video URL this job imports (nil from older backends).
    var url: String? = nil

    /// Places that were saved successfully and have full details.
    var savedPlaces: [DetailPlace] {
        places.filter { $0.status == .saved }.compactMap { $0.place }
    }
}

/// Result of starting an import: either a background job, or an immediate sync result.
enum ImportStartResult {
    case job(id: String)
    case places([DetailPlace])
}
