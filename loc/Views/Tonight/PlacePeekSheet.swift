//
//  PlacePeekSheet.swift
//  loc
//
//  Pushes a place's full detail inside the host NavigationStack of the Tonight / group pick flow, so the
//  flow underneath (vibe, page, scroll position, votes, selections) stays exactly as it was.
//  Dismissing restores the map's previous place selection.
//

import SwiftUI

/// Hashable wrapper (by id) so DetailPlace can drive navigationDestination(item:).
private struct PeekedPlace: Hashable {
    let place: DetailPlace
    static func == (a: PeekedPlace, b: PeekedPlace) -> Bool { a.place.id == b.place.id }
    func hash(into h: inout Hasher) { h.combine(place.id) }
}

private struct PlacePeekModifier: ViewModifier {
    @Binding var place: DetailPlace?
    let source: String
    /// Optional "Show on map" action (leaves the flow on purpose).
    var onShowOnMap: ((DetailPlace) -> Void)?

    @EnvironmentObject private var selectedPlaceVM: SelectedPlaceViewModel
    @State private var previousSelection: DetailPlace?
    @State private var hadSelection = false

    func body(content: Content) -> some View {
        content
            .onChange(of: place?.id) { oldValue, newValue in
                if newValue != nil {
                    if !hadSelection { previousSelection = selectedPlaceVM.selectedPlace }
                    hadSelection = true
                    Analytics.track(.placePeekOpened, ["source": source])
                } else if oldValue != nil {
                    restoreSelection()
                }
            }
            // Pushed inside the host's NavigationStack (same sheet, system back button),
            // so popping returns to the candidate list exactly where it was.
            .navigationDestination(item: Binding(
                get: { place.map(PeekedPlace.init) },
                set: { place = $0?.place }
            )) { (peekedItem: PeekedPlace) in
                let peeked = peekedItem.place
                PlaceDetailViewInNavigation(placeId: peeked.id.uuidString, minSheetHeight: 250, shouldAnimateMap: false)
                    .toolbar(.visible, for: .navigationBar)
                    .toolbar {
                        if let onShowOnMap {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button {
                                    place = nil
                                    onShowOnMap(peeked)
                                } label: {
                                    Label("Map", systemImage: "map")
                                }
                            }
                        }
                    }
            }
    }

    private func restoreSelection() {
        guard hadSelection else { return }
        hadSelection = false
        if let previousSelection {
            selectedPlaceVM.selectPlace(previousSelection, shouldAnimateMap: false)
        } else {
            selectedPlaceVM.selectedPlace = nil
        }
        previousSelection = nil
    }
}

extension View {
    /// Pushes `place` onto the enclosing NavigationStack. Host must be inside a NavigationStack.
    func placePeek(_ place: Binding<DetailPlace?>, source: String, onShowOnMap: ((DetailPlace) -> Void)? = nil) -> some View {
        modifier(PlacePeekModifier(place: place, source: source, onShowOnMap: onShowOnMap))
    }
}
