//
//  ListMapSheetPresentation.swift
//  loc
//
//  Presentation settings for the map-first list sheet: three resting heights (peek, half, full)
//  with the map staying interactive behind the sheet up to half height, like Apple Maps.
//

import SwiftUI

struct ListMapSheetPresentationModifier: ViewModifier {
    @ObservedObject private var sheetVM = ListMapSheetViewModel.shared

    func body(content: Content) -> some View {
        content
            .presentationDetents(
                ListSheetDetent.allPresentationDetents,
                selection: Binding<PresentationDetent>(
                    get: { sheetVM.detent.presentationDetent },
                    set: { sheetVM.userChangedDetent($0) }
                )
            )
            .presentationDragIndicator(.visible)
            .presentationBackground(Color(.systemBackground))
            .presentationCornerRadius(24)
            .presentationBackgroundInteraction(.enabled(upThrough: ListSheetDetent.half.presentationDetent))
    }
}

extension View {
    /// Applies the three-height, map-interactive presentation used by list sheets.
    func applyListMapSheetPresentation() -> some View {
        modifier(ListMapSheetPresentationModifier())
    }
}
