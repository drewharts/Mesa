//
//  ExplorePlaceDestinationView.swift
//  loc
//
//  A place page pushed inside the Explore sheet; publishes the place's name as the sheet strip's title.
//

import SwiftUI

/// Place detail page that reports its header (back + place name) to the sheet's strip.
struct ExplorePlaceDestinationView: View {
    let placeId: String
    let onHeader: (TabSheetHeader) -> Void
    let onBack: () -> Void

    @EnvironmentObject private var detailPlaceViewModel: DetailPlaceViewModel

    /// The place's display name once it is known, else empty.
    private var title: String {
        detailPlaceViewModel.places[placeId]?.displayName ?? ""
    }

    var body: some View {
        PlaceDetailViewInNavigation(placeId: placeId, minSheetHeight: 250, shouldAnimateMap: true)
            .onAppear { publishHeader() }
            .onChange(of: title) { _, _ in publishHeader() }
    }

    /// Sends the place's header to the sheet's strip.
    private func publishHeader() {
        onHeader(TabSheetHeader(id: "place-\(placeId)", title: title, creator: nil, detail: nil, onBack: onBack, onShare: nil))
    }
}
