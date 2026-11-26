//  PlaceOpeningHours.swift
//  loc
//
//  Optional, lenient model of Google regularOpeningHours periods (day 0 = Sunday).

import Foundation

struct PlaceOpeningHours: Codable, Equatable {
    struct Point: Codable, Equatable {
        let day: Int
        let hour: Int
        let minute: Int

        var minuteOfWeek: Int { day * 1440 + hour * 60 + minute }
    }
    struct Period: Codable, Equatable {
        let open: Point
        let close: Point?
    }

    let periods: [Period]

    private enum CodingKeys: String, CodingKey { case periods }

    /// Creates hours from explicit periods.
    init(periods: [Period]) { self.periods = periods }

    /// Decodes leniently: any unexpected shape yields no periods (unknown) instead of failing the payload.
    init(from decoder: Decoder) throws {
        let container = try? decoder.container(keyedBy: CodingKeys.self)
        periods = (try? container?.decodeIfPresent([Period].self, forKey: .periods)) ?? []
    }

    /// Whether the place is open at the given local day-of-week (0 = Sunday) and minute of day; nil when hours are unknown.
    func isOpen(weekday: Int, minuteOfDay: Int) -> Bool? {
        guard !periods.isEmpty else { return nil }
        let now = weekday * 1440 + minuteOfDay
        let week = 7 * 1440
        for period in periods {
            guard let close = period.close else { return true } // open 24/7
            let start = period.open.minuteOfWeek
            var end = close.minuteOfWeek
            if end <= start { end += week }
            if (now >= start && now < end) || (now + week >= start && now + week < end) { return true }
        }
        return false
    }

    /// Whether the place is open at an instant, interpreted in the given UTC offset (seconds); nil when unknown.
    func isOpen(at date: Date, utcOffsetSeconds: Int) -> Bool? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: utcOffsetSeconds) ?? TimeZone(identifier: "UTC")!
        let parts = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        guard let weekday = parts.weekday, let hour = parts.hour, let minute = parts.minute else { return nil }
        return isOpen(weekday: weekday - 1, minuteOfDay: hour * 60 + minute)
    }
}
