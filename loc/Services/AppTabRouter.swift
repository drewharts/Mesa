//
//  AppTabRouter.swift
//  loc
//
//  Single source of truth for the selected bottom tab.
//  Anything that opens a map sheet (deep links, share extension, imports, search) asks this
//  router for the Map tab instead of knowing about the TabView.
//

import Foundation

/// Holds the selected tab so any layer can route the user to a tab without a view reference.
@MainActor
final class AppTabRouter: ObservableObject {
    static let shared = AppTabRouter()

    private init() {}

    /// The tab currently shown.
    @Published var selected: AppTab = .map

    /// Switches to the given tab; no-op when it is already selected.
    func select(_ tab: AppTab) {
        guard selected != tab else { return }
        selected = tab
    }

    /// Switches to the given tab and runs `action` once it is on screen (immediately when already selected).
    func select(_ tab: AppTab, then action: @escaping @MainActor () -> Void) {
        guard selected != tab else {
            action()
            return
        }
        selected = tab
        Task { @MainActor in
            // Sheets and navigation need the destination tab to finish appearing first.
            try? await Task.sleep(nanoseconds: 400_000_000)
            action()
        }
    }
}
