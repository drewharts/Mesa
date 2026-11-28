//
//  DamnlinesWaitInfo.swift
//  loc
//
//  Wait-time data for one venue from the damnlines.com line index (CC BY 4.0).
//

import Foundation

struct DamnlinesWaitInfo: Equatable {
    let venueName: String
    let averageWaitMinutes: Int
    let peakWaitMinutes: Int
    let peakDay: String
    let peakHourLocal: String
    let pageURL: URL

    /// Returns the summary line, e.g. "Usually ~18 min wait · peaks ~26 min Sat 5 PM".
    var summaryText: String {
        "Usually ~\(averageWaitMinutes) min wait · peaks ~\(peakWaitMinutes) min \(Self.abbreviate(day: peakDay)) \(peakHourLocal)"
    }

    /// Abbreviates a full English weekday name to its first three letters; unknown input passes through.
    static func abbreviate(day: String) -> String {
        let full = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        return full.contains(day) ? String(day.prefix(3)) : day
    }
}

/// Decodable shape of https://damnlines.com/data/line-index (only the fields Mesa uses).
struct DamnlinesLineIndex: Decodable {
    struct Peak: Decodable {
        let waitMinutes: Int
        let day: String
        let hourLocal: String

        enum CodingKeys: String, CodingKey {
            case waitMinutes = "wait_minutes", day, hourLocal = "hour_local"
        }
    }

    struct Venue: Decodable {
        let venue: String
        let page: String
        let averageWaitMinutes: Int
        let peak: Peak

        enum CodingKeys: String, CodingKey {
            case venue, page, peak, averageWaitMinutes = "average_wait_minutes"
        }
    }

    let venues: [Venue]
}
