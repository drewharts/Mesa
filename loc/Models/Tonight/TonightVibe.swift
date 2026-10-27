//
//  TonightVibe.swift
//  loc
//
//  The kind of outing Tonight ranks for. Inferred from the time of day so
//  Tonight can show picks instantly with zero input; the user may override it.
//

import Foundation

enum TonightVibe: String, CaseIterable, Identifiable, Codable {
    case coffee
    case lunch
    case dinner
    case drinks
    case lateNight

    var id: String { rawValue }

    /// Short chip label.
    var label: String {
        switch self {
        case .coffee: return "Coffee"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .drinks: return "Drinks"
        case .lateNight: return "Late night"
        }
    }

    /// SF Symbol shown on the chip.
    var symbol: String {
        switch self {
        case .coffee: return "cup.and.saucer.fill"
        case .lunch: return "takeoutbag.and.cup.and.straw.fill"
        case .dinner: return "fork.knife"
        case .drinks: return "wineglass.fill"
        case .lateNight: return "moon.stars.fill"
        }
    }

    /// Title for the Tonight sheet header ("Coffee near you").
    var headline: String {
        switch self {
        case .coffee: return "Coffee right now"
        case .lunch: return "Lunch spots"
        case .dinner: return "Dinner tonight"
        case .drinks: return "Drinks tonight"
        case .lateNight: return "Late night"
        }
    }

    /// Returns the vibe that best fits the given local hour (0-23).
    static func inferred(forHour hour: Int) -> TonightVibe {
        switch hour {
        case 5..<11: return .coffee
        case 11..<15: return .lunch
        case 15..<17: return .coffee
        case 17..<21: return .dinner
        case 21..<24: return .drinks
        default: return .lateNight
        }
    }

    /// Returns the vibe for the current moment in the user's calendar/time zone.
    static func inferred(now: Date = Date(), calendar: Calendar = .current) -> TonightVibe {
        inferred(forHour: calendar.component(.hour, from: now))
    }

    // Eligibility and fit per vibe live in TonightCategoryClassifier.
}
