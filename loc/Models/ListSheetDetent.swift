//
//  ListSheetDetent.swift
//  loc
//
//  The three resting heights of the map-first list sheet (peek / half / full),
//  mapped to SwiftUI presentation detents. Pure value type.
//

import SwiftUI

enum ListSheetDetent: String, CaseIterable {
    case peek
    case half
    case full

    /// Height of the collapsed sheet: drag handle, list title and place count.
    static let peekHeight: CGFloat = 160

    /// Detent used when a list opens.
    static let `default`: ListSheetDetent = .half

    var presentationDetent: PresentationDetent {
        switch self {
        case .peek: return .height(Self.peekHeight)
        case .half: return .fraction(0.5)
        case .full: return .large
        }
    }

    /// Fraction of the screen the sheet covers at this detent (used to center pins in the visible map area).
    var screenFraction: CGFloat {
        switch self {
        case .peek:
            let screenHeight = max(UIScreen.main.bounds.height, 1)
            return min(Self.peekHeight / screenHeight, 0.5)
        case .half: return 0.5
        case .full: return 0.9
        }
    }

    /// Maps a SwiftUI detent back to one of the three heights.
    init?(_ detent: PresentationDetent) {
        if detent == ListSheetDetent.peek.presentationDetent {
            self = .peek
        } else if detent == ListSheetDetent.half.presentationDetent {
            self = .half
        } else if detent == ListSheetDetent.full.presentationDetent {
            self = .full
        } else {
            return nil
        }
    }

    static var allPresentationDetents: Set<PresentationDetent> {
        Set(allCases.map { $0.presentationDetent })
    }
}
