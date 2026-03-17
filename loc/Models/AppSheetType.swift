//
//  AppSheetType.swift
//  loc
//
//  Unified enum for all sheet types in the app.
//  Used by PresentationService to manage single-sheet presentation.
//

import CoreLocation
import Foundation

/// Unified enum representing all possible sheet types in the app.
/// Single source of truth for sheet presentation to avoid SwiftUI conflicts.
enum AppSheetType: Identifiable, Equatable {
    // MARK: - Place Detail

    case placeDetail

    // MARK: - External Content Import

    case externalPlaceSelection
    case noPlacesFound(contentUrl: String)
    case importPlaceConfirmation(placeId: String, contentUrl: String)

    // MARK: - Map Popups (User's Own Data)

    case list(listId: String)
    case externalVideos
    case reviews
    case favorites
    case myPlaces

    // MARK: - Map Popups (External User Data)

    case externalReviews
    case externalList(listId: String)
    case externalFavorites

    // MARK: - Search Results

    case keywordResults(keyword: String, types: [String])

    // MARK: - Nearby Discovery

    case nearbyDiscovery

    // MARK: - City Overview

    case cityOverview(cityName: String, coordinate: CLLocationCoordinate2D, annotation: CityAnnotation?)

    // MARK: - Trips

    case tripsList

    // MARK: - Onboarding

    case suggestedProfiles

    // MARK: - Identifiable

    var id: String {
        switch self {
        case .placeDetail:
            return "placeDetail"
        case .externalPlaceSelection:
            return "externalPlaceSelection"
        case .noPlacesFound(let contentUrl):
            return "noPlacesFound-\(contentUrl)"
        case .importPlaceConfirmation(let placeId, let contentUrl):
            return "importPlaceConfirmation-\(placeId)-\(contentUrl)"
        case .list(let listId):
            return "list-\(listId)"
        case .externalVideos:
            return "externalVideos"
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
        case .nearbyDiscovery:
            return "nearbyDiscovery"
        case .cityOverview(let cityName, _, _):
            return "cityOverview-\(cityName)"
        case .tripsList:
            return "tripsList"
        case .suggestedProfiles:
            return "suggestedProfiles"
        }
    }

    // MARK: - Equatable

    static func == (lhs: AppSheetType, rhs: AppSheetType) -> Bool {
        switch (lhs, rhs) {
        case (.placeDetail, .placeDetail):
            return true
        case (.externalPlaceSelection, .externalPlaceSelection):
            return true
        case (.noPlacesFound(let lhsUrl), .noPlacesFound(let rhsUrl)):
            return lhsUrl == rhsUrl
        case (.importPlaceConfirmation(let lhsId, let lhsUrl), .importPlaceConfirmation(let rhsId, let rhsUrl)):
            return lhsId == rhsId && lhsUrl == rhsUrl
        case (.list(let lhsId), .list(let rhsId)):
            return lhsId == rhsId
        case (.externalVideos, .externalVideos):
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
        case (.nearbyDiscovery, .nearbyDiscovery):
            return true
        case (.tripsList, .tripsList):
            return true
        case (.suggestedProfiles, .suggestedProfiles):
            return true
        case (.cityOverview(let lhsName, _, _), .cityOverview(let rhsName, _, _)):
            return lhsName == rhsName
        default:
            return false
        }
    }
}
