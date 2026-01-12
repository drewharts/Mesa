//
//  ListPopupContainerView.swift
//  loc
//
//  DEPRECATED: This view is no longer used.
//  List popup is now presented via native SwiftUI sheet in MapContainerView.
//  Keeping for reference but can be deleted.
//

import SwiftUI

/// DEPRECATED: Container that managed list popup sheet presentation on map
/// Now replaced by .sheet(item:) in MapContainerView
struct ListPopupContainerView: View {
    @EnvironmentObject var mapViewModel: MapViewModel
    @EnvironmentObject var profileViewModel: ProfileViewModel

    @Binding var sheetHeight: CGFloat
    let minSheetHeight: CGFloat
    let maxSheetHeight: CGFloat

    var body: some View {
        // This view is deprecated - list popup is now handled by MapContainerView
        EmptyView()
    }
}
