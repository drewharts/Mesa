//
//  TabSheetHeader.swift
//  loc
//
//  What the tab sheet's fixed header strip shows while a destination is pushed on top of a tab's root.
//

import Foundation

/// Header content of a pushed destination: back + title, optional share, and an optional creator/detail line.
struct TabSheetHeader {
    /// Who made the pushed list; shown as a chip on the detail line.
    struct Creator {
        let name: String
        let photoURL: String?
        /// Opens the creator's profile; nil when the chip isn't tappable.
        let onTap: (() -> Void)?
    }

    /// Stable identity of the destination, so the strip animates only when the destination changes.
    let id: String
    let title: String
    let creator: Creator?
    /// Trailing text of the detail line (e.g. "75 places").
    let detail: String?
    let onBack: () -> Void
    /// Share action; nil hides the share button.
    let onShare: (() -> Void)?
    /// "Find a table" action; non-nil shows the compact button trailing the detail line.
    var onFindTable: (() -> Void)? = nil

    /// True when there is a second line (creator chip and/or detail text).
    var hasDetailLine: Bool { creator != nil || detail != nil || onFindTable != nil }
}
