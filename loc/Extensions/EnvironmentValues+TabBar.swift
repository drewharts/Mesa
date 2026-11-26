//
//  EnvironmentValues+TabBar.swift
//  loc
//
//  Publishes the measured tab bar position so full-bleed content (the map) can keep its overlays clear of the bar.
//

import SwiftUI

private struct TabBarTopKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    /// Screen-space y of the tab bar's top edge; 0 until measured.
    var tabBarTop: CGFloat {
        get { self[TabBarTopKey.self] }
        set { self[TabBarTopKey.self] = newValue }
    }
}

enum TabBarClearance {
    /// Gap kept between floating map controls and the tab bar's top edge.
    static let margin: CGFloat = 12
    /// Tab bar height plus home-indicator area, used until the bar's position has been measured.
    static let fallbackHeight: CGFloat = 96

    /// Returns how much of a view's bottom edge (screen y) the tab bar covers, or the fallback height if unmeasured.
    static func overlap(containerBottom: CGFloat, tabBarTop: CGFloat) -> CGFloat {
        tabBarTop > 0 ? max(0, containerBottom - tabBarTop) : fallbackHeight
    }
}
