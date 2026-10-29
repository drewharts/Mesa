//
//  PlacePeekSheet.swift
//  loc
//
//  Shows a place's full detail as a sheet stacked over the Tonight / group pick flow, so the
//  flow underneath (vibe, page, scroll position, votes, selections) stays exactly as it was.
//  Dismissing restores the map's previous place selection.
//

import SwiftUI

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
            .onChange(of: place?.id) { _, newValue in
                guard newValue != nil else { return }
                previousSelection = selectedPlaceVM.selectedPlace
                hadSelection = true
                Analytics.track(.placePeekOpened, ["source": source])
            }
            .sheet(item: $place, onDismiss: restoreSelection) { peeked in
                NavigationStack {
                    PlaceDetailViewInNavigation(placeId: peeked.id.uuidString, minSheetHeight: 250, shouldAnimateMap: false)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { place = nil }
                            }
                            if let onShowOnMap {
                                ToolbarItem(placement: .cancellationAction) {
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
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
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
    /// Presents `place` as a detail sheet over the current flow without dismissing it.
    func placePeek(_ place: Binding<DetailPlace?>, source: String, onShowOnMap: ((DetailPlace) -> Void)? = nil) -> some View {
        modifier(PlacePeekModifier(place: place, source: source, onShowOnMap: onShowOnMap))
    }
}
