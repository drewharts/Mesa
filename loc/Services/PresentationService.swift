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
        // Re-assigning the same sheet makes SwiftUI re-run detent/presentation work (visible hitch).
        pendingTransition?.cancel()
        guard activeSheet != sheet else { return }
        activeSheet = sheet
    }

    private var pendingTransition: Task<Void, Never>?
    private var lastDismissAt: Date?

    /// Swaps the current sheet for `sheet` as ONE sequenced transition: if a different sheet is up,
    /// dismiss it first and present the new one once the dismissal has finished, instead of
    /// nil→new in the same runloop (which makes UIKit overlap a dismiss and a present).
    func transition(to sheet: AppSheetType) {
        pendingTransition?.cancel()
        let dismissDuration: TimeInterval = 0.35
        var delay: TimeInterval = 0
        if let current = activeSheet {
            if current == sheet { return }   // already showing: no redundant detent reset
            dismiss()
            delay = dismissDuration
        } else if let lastDismissAt {
            // A caller dismissed another sheet just before asking for this one.
            delay = max(0, dismissDuration - Date().timeIntervalSince(lastDismissAt))
        }
        guard delay > 0.01 else {
            withAnimation(.placeOpen) { present(sheet) }
            return
        }
        pendingTransition = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard let self, !Task.isCancelled, self.activeSheet == nil else { return }
            withAnimation(.placeOpen) { self.present(sheet) }
        }
    }

    /// Presents a sheet immediately with minimal animation.
    func presentImmediately(_ sheet: AppSheetType) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            activeSheet = sheet
        }
    }

    /// Dismisses the currently active sheet.
    func dismiss() {
        pendingTransition?.cancel()
        if activeSheet != nil { lastDismissAt = Date() }
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
        case .list, .externalVideos, .reviews, .favorites, .myPlaces,
             .externalReviews, .externalList, .externalFavorites, .keywordResults,
             .nearbyDiscovery:
            return true
        default:
            return false
        }
    }

    /// Checks if any sheet is currently presented.
    var hasActiveSheet: Bool {
        activeSheet != nil
    }

    // MARK: - Sheet Preservation (for profile navigation round-trips)

    /// Saved sheet to restore after returning from profile navigation.
    @Published var preservedSheet: AppSheetType? = nil

    /// Saves the active sheet for later restoration (e.g., after profile navigation).
    func preserveAndDismiss() {
        preservedSheet = activeSheet
        activeSheet = nil
    }

    /// Restores a previously preserved sheet, if any.
    func restorePreservedSheet() {
        if let sheet = preservedSheet {
            activeSheet = sheet
            preservedSheet = nil
        }
    }
}


extension Animation {
    /// Single timing shared by every piece of the "open a place" transition
    /// (sheet swap, detail sheet content, map camera) so they move together.
    static let placeOpen = Animation.spring(response: 0.38, dampingFraction: 0.9)
}
