//
//  TabSheetDetent.swift
//  loc
//
//  The resting heights of the Explore / Trips / Profile bottom sheet that sits over the map.
//

import CoreGraphics

/// Where the tab sheet rests: half the map area (map stays usable above it) or nearly full.
enum TabSheetDetent {
    case medium
    case large

    /// Fraction of the available map area the sheet covers at this detent.
    var fraction: CGFloat {
        switch self {
        case .medium: return 0.5
        case .large: return 1
        }
    }

    /// Sheet height inside a container of the given height.
    func height(in containerHeight: CGFloat) -> CGFloat {
        containerHeight * fraction
    }
}
