//
//  AppSheetType.swift
//  loc
//
//  Unified enum for all sheet types in the app.
//  Used by PresentationService to manage single-sheet presentation.
//

import Foundation

/// Unified enum representing all possible sheet types in the app.
/// Single source of truth for sheet presentation to avoid SwiftUI conflicts.
enum AppSheetType: Identifiable, Equatable {
    // MARK: - Place Detail

    case placeDetail

    // MARK: - TikTok Import

    case tikTokPlaceSelection
    case tikTokNoPlacesFound(tikTokUrl: String)

    // MARK: - Map Popups (User's Own Data)

    case list(listId: String)
    case tiktoks
    case reviews
    case favorites
    case myPlaces

    // MARK: - Map Popups (External User Data)

    case externalReviews
    case externalList(listId: String)
    case externalFavorites

    // MARK: - Search Results

    case keywordResults(keyword: String, types: [String])

    // MARK: - Onboarding

    case suggestedProfiles

    // MARK: - Identifiable

    var id: String {
        switch self {
        case .placeDetail:
            return "placeDetail"
        case .tikTokPlaceSelection:
            return "tikTokPlaceSelection"
        case .tikTokNoPlacesFound(let tikTokUrl):
            return "tikTokNoPlacesFound-\(tikTokUrl)"
        case .list(let listId):
            return "list-\(listId)"
        case .tiktoks:
            return "tiktoks"
        case .reviews:
            return "reviews"
        case .favorites:
            return "favorites"
        case .myPlaces:
            return "myPlaces"
        case .externalReviews:
            return "externalReviews"
        case .externalList(let listId):
            return "externalList-\(listId)"
        case .externalFavorites:
            return "externalFavorites"
        case .keywordResults(let keyword, _):
            return "keywordResults-\(keyword)"
        case .suggestedProfiles:
            return "suggestedProfiles"
        }
    }

    // MARK: - Equatable

    static func == (lhs: AppSheetType, rhs: AppSheetType) -> Bool {
        switch (lhs, rhs) {
        case (.placeDetail, .placeDetail):
            return true
        case (.tikTokPlaceSelection, .tikTokPlaceSelection):
            return true
        case (.tikTokNoPlacesFound(let lhsUrl), .tikTokNoPlacesFound(let rhsUrl)):
            return lhsUrl == rhsUrl
        case (.list(let lhsId), .list(let rhsId)):
            return lhsId == rhsId
        case (.tiktoks, .tiktoks):
            return true
        case (.reviews, .reviews):
            return true
        case (.favorites, .favorites):
            return true
        case (.myPlaces, .myPlaces):
            return true
        case (.externalReviews, .externalReviews):
            return true
        case (.externalList(let lhsId), .externalList(let rhsId)):
            return lhsId == rhsId
        case (.externalFavorites, .externalFavorites):
            return true
        case (.keywordResults(let lhsKeyword, let lhsTypes), .keywordResults(let rhsKeyword, let rhsTypes)):
            return lhsKeyword == rhsKeyword && lhsTypes == rhsTypes
        case (.suggestedProfiles, .suggestedProfiles):
            return true
        default:
            return false
        }
    }
}
