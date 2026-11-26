//
//  AppTabRouter.swift
//  loc
//
//  Single source of truth for the selected bottom tab.
//  The map is always the base layer: `.map` means no tab sheet is up, any other tab means that
//  tab's content is shown as a bottom sheet over the map. Anything that opens a map sheet (deep
//  links, share extension, imports, search, "open this list") asks this router for the Map tab
//  instead of knowing about the tab bar.
//

import Foundation

/// Holds the selected tab so any layer can route the user to a tab without a view reference.
@MainActor
final class AppTabRouter: ObservableObject {
    static let shared = AppTabRouter()

    private init() {}

    /// The tab currently selected (`.map` when no tab sheet is showing).
    @Published var selected: AppTab = .map {
        didSet { if selected != .map { visitedTabs.insert(selected) } }
    }

    /// Tabs whose sheet content has been shown at least once; their views stay alive so scroll position and loaded data survive.
    @Published private(set) var visitedTabs: Set<AppTab> = []

    /// The tab whose sheet was lowered to show map content (a list, a place); restored when that content closes.
    private(set) var returnTab: AppTab?

    /// Switches to the given tab; no-op when it is already selected. A manual switch forgets any pending return.
    func select(_ tab: AppTab) {
        returnTab = nil
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

    // MARK: - Map Handoff

    /// Collapses the current tab sheet so the map is fully visible, remembers the tab to return to, and runs `action`
    /// (typically presenting a list or place sheet). Closing that content brings the tab sheet back.
    func handOffToMap(then action: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            await handOffToMap()
            action()
        }
    }

    /// Collapses the current tab sheet, remembers the tab to return to, and returns once the sheet has started sliding away.
    func handOffToMap() async {
        if selected != .map { returnTab = selected }
        selected = .map
        // Let the tab sheet start sliding away so the map sheet is not presented mid-transition.
        try? await Task.sleep(nanoseconds: 120_000_000)
    }

    /// Brings back the tab sheet the user came from, if the map is still showing and nothing else moved them.
    func restoreReturnTab() {
        guard let tab = returnTab else { return }
        returnTab = nil
        guard selected == .map else { return }
        selected = tab
    }

    /// Forgets the tab to return to (the user went elsewhere).
    func clearReturnTab() {
        returnTab = nil
    }
}
