//
//  TabSheetViewModel.swift
//  loc
//
//  Owns the resting height of the tab bottom sheet (Explore / Trips / Profile over the map) and
//  decides which height a finished drag settles on. The view only reports drag distances.
//

import CoreGraphics
import Foundation

@MainActor
final class TabSheetViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var detent: TabSheetDetent = .large

    /// Header of the destination pushed on the active tab (nil at the tab's root); the sheet's strip shows it.
    @Published private(set) var pushedHeader: TabSheetHeader?

    /// The height to return to once whatever required the lowered sheet (a pushed list or trip) is gone.
    private var detentBeforeLowering: TabSheetDetent?

    // MARK: - Header

    /// Sets (or with nil clears) the pushed destination's header shown in the sheet's strip.
    func setPushedHeader(_ header: TabSheetHeader?) {
        pushedHeader = header
    }

    // MARK: - Detent Changes

    /// Raises the sheet to its large height (the default whenever a tab opens).
    func presentAtLarge() {
        detentBeforeLowering = nil
        detent = .large
    }

    /// Lowers the sheet to medium so the map's pins are visible above it, remembering the height to return to.
    func lowerToMedium() {
        if detentBeforeLowering == nil { detentBeforeLowering = detent }
        detent = .medium
    }

    /// Returns the sheet to the height it had before `lowerToMedium` (no-op when it was not lowered).
    func restoreFromLowered() {
        guard let previous = detentBeforeLowering else { return }
        detentBeforeLowering = nil
        detent = previous
    }

    /// Settles on the nearest detent after a drag, projecting the finger's momentum; dragging up grows the sheet.
    /// Returns true when the drag ended low enough that the sheet should be dismissed entirely instead.
    func settle(afterDragTranslation translation: CGFloat, predictedTranslation: CGFloat, containerHeight: CGFloat) -> Bool {
        guard containerHeight > 0 else { return false }
        detentBeforeLowering = nil
        let projected = detent.height(in: containerHeight) - (translation + (predictedTranslation - translation) * 0.35)
        let medium = TabSheetDetent.medium.height(in: containerHeight)
        let large = TabSheetDetent.large.height(in: containerHeight)
        if projected < medium * Self.dismissFraction { return true }
        detent = abs(projected - medium) < abs(projected - large) ? .medium : .large
        return false
    }

    /// A drag projected below this fraction of the medium height dismisses the sheet.
    private static let dismissFraction: CGFloat = 0.6
}
