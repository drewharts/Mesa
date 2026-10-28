//
//  PlaceHours.swift
//  loc
//
//  Parses the opening hours we already store on `places.open_hours` (Google weekday text, as
//  [{day, hours}] objects or "Monday: 11 AM–10 PM" strings) and evaluates open/closed at a moment
//  in the place's time zone. Handles split ranges ("12–2 PM, 7:30–9 PM"), shared AM/PM,
//  overnight ranges ("6 PM–2 AM"), "Open 24 hours" and "Closed". Pure value type, no I/O.
//

import Foundation

struct PlaceHours: Equatable {
    /// Minutes-from-week-start ranges (Sunday 00:00 = 0). Close may exceed one week (wraps).
    private let ranges: [(open: Int, close: Int)]
    let isAlwaysOpen: Bool

    static func == (lhs: PlaceHours, rhs: PlaceHours) -> Bool {
        lhs.isAlwaysOpen == rhs.isAlwaysOpen
            && lhs.ranges.map { [$0.open, $0.close] } == rhs.ranges.map { [$0.open, $0.close] }
    }

    private static let week = 7 * 24 * 60
    private static let dayIndex: [String: Int] = [
        "sunday": 0, "monday": 1, "tuesday": 2, "wednesday": 3,
        "thursday": 4, "friday": 5, "saturday": 6
    ]

    // MARK: - Parsing

    /// Parses "Day: hours" lines. Returns nil when nothing usable is found (hours unknown).
    init?(weekdayText lines: [String]) {
        var pairs: [(String, String)] = []
        for line in lines {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let day = String(line[..<colon])
            let hours = String(line[line.index(after: colon)...])
            pairs.append((day, hours))
        }
        self.init(dayHours: pairs)
    }

    /// Parses (day, hours) pairs.
    init?(dayHours: [(day: String, hours: String)]) {
        var ranges: [(Int, Int)] = []
        var knownDays = 0
        var allDay = 0
        for (rawDay, rawHours) in dayHours {
            guard let day = Self.dayIndex[rawDay.trimmingCharacters(in: .whitespaces).lowercased()] else { continue }
            let hours = Self.normalize(rawHours)
            let lower = hours.lowercased()
            knownDays += 1
            if lower.isEmpty { knownDays -= 1; continue }
            if lower.contains("closed") { continue }
            if lower.contains("24 hours") {
                allDay += 1
                ranges.append((day * 1440, day * 1440 + 1440))
                continue
            }
            for part in hours.split(separator: ",") {
                guard let (open, close) = Self.parseRange(String(part)) else { continue }
                let start = day * 1440 + open
                var end = day * 1440 + close
                if end <= start { end += 1440 } // overnight
                ranges.append((start, end))
            }
        }
        guard knownDays > 0 else { return nil }
        if ranges.isEmpty && knownDays < 7 { return nil }
        self.ranges = ranges
        self.isAlwaysOpen = allDay == 7
    }

    private static func normalize(_ s: String) -> String {
        s.replacingOccurrences(of: "\u{2009}", with: " ")
            .replacingOccurrences(of: "\u{202F}", with: " ")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: " to ", with: "-")
            .trimmingCharacters(in: .whitespaces)
    }

    /// "11:30 AM-11 PM", "12-2 PM", "6 PM-2 AM", "09:00-17:00".
    private static func parseRange(_ text: String) -> (Int, Int)? {
        let sides = text.split(separator: "-", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        guard sides.count == 2 else { return nil }
        guard let close = parseTime(sides[1], fallbackMeridiem: nil) else { return nil }
        let closeMeridiem = meridiem(of: sides[1])
        var open = parseTime(sides[0], fallbackMeridiem: closeMeridiem)
        // "11-2 PM": if sharing the meridiem would put open after close, the open is AM.
        if meridiem(of: sides[0]) == nil, closeMeridiem == "pm", let o = open, o > close.minutes {
            open = (o.minutes - 720, o.hasMeridiem)
        }
        guard let open else { return nil }
        return (open.minutes, close.minutes % 1440)
    }

    private static func meridiem(of s: String) -> String? {
        let l = s.lowercased()
        if l.contains("am") { return "am" }
        if l.contains("pm") { return "pm" }
        return nil
    }

    private static func parseTime(_ s: String, fallbackMeridiem: String?) -> (minutes: Int, hasMeridiem: Bool)? {
        let l = s.lowercased()
        let mer = meridiem(of: l) ?? fallbackMeridiem
        let digits = l.replacingOccurrences(of: "am", with: "").replacingOccurrences(of: "pm", with: "")
            .trimmingCharacters(in: .whitespaces)
        let parts = digits.split(separator: ":")
        guard let h = Int(parts.first ?? ""), h >= 0, h <= 24 else { return nil }
        let m = parts.count > 1 ? (Int(parts[1].prefix(2)) ?? 0) : 0
        var hour = h
        if let mer {
            if mer == "am" { hour = (h == 12) ? 0 : h }
            else { hour = (h == 12) ? 12 : h + 12 }
        }
        return (hour * 60 + m, mer != nil)
    }

    // MARK: - Evaluation

    struct State: Equatable {
        let isOpen: Bool
        let isAlwaysOpen: Bool
        /// Next open/close moment, nil for 24/7 or never-open.
        let nextChange: Date?
    }

    func state(at date: Date = Date(), timeZone: TimeZone = .current) -> State {
        if isAlwaysOpen { return State(isOpen: true, isAlwaysOpen: true, nextChange: nil) }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let c = cal.dateComponents([.weekday, .hour, .minute], from: date)
        let now = ((c.weekday ?? 1) - 1) * 1440 + (c.hour ?? 0) * 60 + (c.minute ?? 0)

        // Merge-free check across this week and the wrap from last week.
        var closeAt: Int?
        for r in ranges {
            for shift in [0, -Self.week] {
                let o = r.open + shift, cl = r.close + shift
                if now >= o && now < cl { closeAt = max(closeAt ?? cl, cl) }
            }
        }
        if let closeAt {
            // Extend through back-to-back ranges (e.g. "Open 24 hours" days in a row).
            var end = closeAt
            var extended = true
            while extended {
                extended = false
                for r in ranges {
                    for shift in [0, Self.week, -Self.week] where r.open + shift <= end && r.close + shift > end {
                        end = r.close + shift; extended = true
                    }
                }
                if end - now > Self.week { return State(isOpen: true, isAlwaysOpen: true, nextChange: nil) }
            }
            return State(isOpen: true, isAlwaysOpen: false, nextChange: date.addingTimeInterval(TimeInterval((end - now) * 60)))
        }
        let nextOpen = ranges.map { r -> Int in
            let d = r.open - now
            return d > 0 ? d : d + Self.week
        }.min()
        return State(isOpen: false, isAlwaysOpen: false,
                     nextChange: nextOpen.map { date.addingTimeInterval(TimeInterval($0 * 60)) })
    }

    // MARK: - Display

    /// "Closes 10 PM", "Opens 9 AM", "Opens Sat 12 PM", "Open 24 hours".
    static func changeText(for state: State, now: Date = Date(), timeZone: TimeZone = .current) -> String? {
        if state.isAlwaysOpen { return "Open 24 hours" }
        guard let next = state.nextChange else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let f = DateFormatter()
        f.timeZone = timeZone
        f.locale = Locale(identifier: "en_US")
        let minute = cal.component(.minute, from: next)
        let time = minute == 0 ? "h a" : "h:mm a"
        let hoursAway = next.timeIntervalSince(now) / 3600
        let sameOrNextMorning = cal.isDate(next, inSameDayAs: now) || hoursAway < 12
        f.dateFormat = sameOrNextMorning ? time : "EEE \(time)"
        return "\(state.isOpen ? "Closes" : "Opens") \(f.string(from: next))"
    }
}
