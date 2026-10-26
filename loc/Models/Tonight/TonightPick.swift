//
//  TonightPick.swift
//  loc
//
//  One ranked Tonight recommendation with its one-line reason.
//

import Foundation

struct TonightPick: Identifiable, Equatable {
    /// Supabase place id exactly as stored (used for votes and links).
    let placeId: String
    let place: DetailPlace
    let distanceMeters: Double?
    let isOpenNow: Bool?
    let score: Double
    let reason: String

    var id: String { placeId }
}

/// A place someone in the user's circle saved, with who saved it.
struct TonightCandidate: Equatable {
    let placeId: String
    /// Lowercased user ids of everyone (user and friends) who saved it.
    let saverIds: Set<String>
}
