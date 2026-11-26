//
//  ExploreShortcutSheetView.swift
//  loc
//
//  Sheet content for the Explore tab's shortcut cards.
//

import SwiftUI

/// Hosts Tonight or Fresh finds; opening a place hands off to the caller (which routes to the Map tab).
struct ExploreShortcutSheetView: View {
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var locationManager: LocationManager

    let shortcut: ExploreShortcut
    let onOpenPlace: (DetailPlace) -> Void

    var body: some View {
        switch shortcut {
        case .tonight:
            TonightSheet(userSession: userSession, locationManager: locationManager, onOpenPlace: onOpenPlace)
                .presentationDetents([.medium, .large])
                .presentationContentInteraction(.resizes)
                .presentationDragIndicator(.visible)
        case .freshFinds:
            FreshFindsView(userId: userSession.currentUserId, onShowOnMap: onOpenPlace)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}
