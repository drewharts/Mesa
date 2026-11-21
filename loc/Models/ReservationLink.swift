//
//  ReservationLink.swift
//  loc
//
//  Reservation deep link returned by GET /places/<place_id>/reservation.
//

import Foundation

struct ReservationLink: Codable, Equatable {
    let provider: String?
    let url: String?

    /// Returns the parsed https/http URL, or nil when the backend returned no usable link.
    var destinationURL: URL? {
        guard let raw = url?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty,
              let parsed = URL(string: raw),
              let scheme = parsed.scheme?.lowercased(),
              scheme == "https" || scheme == "http" else { return nil }
        return parsed
    }

    /// Returns the button title, e.g. "Reserve on Resy", or "Reserve" for unknown providers.
    var buttonTitle: String {
        guard let name = Self.providerDisplayName(provider) else { return "Reserve" }
        return "Reserve on \(name)"
    }

    /// Maps a backend provider key to its display name, or nil when unrecognized.
    static func providerDisplayName(_ provider: String?) -> String? {
        let key = (provider ?? "").lowercased().filter { $0.isLetter || $0.isNumber }
        switch key {
        case "resy": return "Resy"
        case "opentable": return "OpenTable"
        case "tock": return "Tock"
        case "sevenrooms": return "SevenRooms"
        case "yelp": return "Yelp"
        default: return nil
        }
    }

    /// Returns the asset catalog name of the provider's logo, or nil when unrecognized.
    static func providerLogoAssetName(_ provider: String?) -> String? {
        providerDisplayName(provider).map { "ReserveLogo\($0)" }
    }

    /// Returns the asset name of this link's provider logo, or nil for unknown providers.
    var logoAssetName: String? { Self.providerLogoAssetName(provider) }

    /// Returns the visible button text, e.g. "Reserve · Resy", or "Reserve" for unknown providers.
    var buttonLabelText: String {
        guard let name = Self.providerDisplayName(provider) else { return "Reserve" }
        return "Reserve · \(name)"
    }

    /// Returns true when a place of these categories is likely to take reservations.
    static func isReservableCategory(_ categories: [String]?) -> Bool {
        let keywords = ["restaurant", "bar", "cafe", "café", "coffee", "bistro", "pub", "brewery", "food"]
        return (categories ?? []).contains { category in
            let lowered = category.lowercased()
            return keywords.contains { lowered.contains($0) }
        }
    }
}
