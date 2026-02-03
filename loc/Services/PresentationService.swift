//
//  PresentationService.swift
//  loc
//
//  Centralized service for all sheet/modal presentation in the app.
//  Single Responsibility: Manage presentation state to prevent SwiftUI sheet conflicts.
//
//  Enterprise Pattern: ViewModels request presentation via this service.
//  They don't hold navigation state - they just call PresentationService.shared.
//

import Foundation
import SwiftUI

/// Centralized service for all sheet presentation across the app.
/// Single source of truth to prevent "only presenting a single sheet is supported" warnings.
@MainActor
class PresentationService: ObservableObject {
    // MARK: - Singleton

    static let shared = PresentationService()

    private init() {}

    // MARK: - Published State

    /// The currently active sheet, or nil if no sheet is presented.
    @Published var activeSheet: AppSheetType? = nil

    /// Pending place navigation - set when map annotation is tapped while a sheet is open.
    /// Sheet views observe this to navigate to the place within their NavigationStack.
    @Published var pendingPlaceNavigation: String? = nil

    // MARK: - Presentation Methods

    /// Presents a sheet of the given type.
    func present(_ sheet: AppSheetType) {
        activeSheet = sheet
    }

    /// Dismisses the currently active sheet.
    func dismiss() {
        activeSheet = nil
    }

    // MARK: - Query Methods

    /// Checks if a specific sheet type is currently active.
    func isPresenting(_ sheet: AppSheetType) -> Bool {
        guard let active = activeSheet else { return false }
        return active == sheet
    }

    /// Checks if place detail sheet is currently active.
    var isShowingPlaceDetail: Bool {
        activeSheet == .placeDetail
    }

    /// Checks if any list popup (own or external) is showing.
    var isShowingAnyListPopup: Bool {
        guard let sheet = activeSheet else { return false }
        switch sheet {
        case .list, .externalList:
            return true
        default:
            return false
        }
    }

    /// Checks if any map popup is currently showing.
    var isShowingMapPopup: Bool {
        guard let sheet = activeSheet else { return false }
        switch sheet {
        case .list, .tiktoks, .reviews, .favorites, .myPlaces,
             .externalReviews, .externalList, .externalFavorites, .keywordResults:
            return true
        default:
            return false
        }
    }

    /// Checks if any sheet is currently presented.
    var hasActiveSheet: Bool {
        activeSheet != nil
    }
}
