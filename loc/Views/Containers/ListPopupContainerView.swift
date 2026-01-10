//
//  ListPopupContainerView.swift
//  loc
//
//  Created by Assistant on list popup overlay
//

import SwiftUI

/// Container that manages list popup sheet presentation on map
struct ListPopupContainerView: View {
    @EnvironmentObject var mapViewModel: MapViewModel
    @EnvironmentObject var profileViewModel: ProfileViewModel
    
    @Binding var sheetHeight: CGFloat
    let minSheetHeight: CGFloat
    let maxSheetHeight: CGFloat
    
    var body: some View {
        Group {
            if mapViewModel.showingListPopup, let listId = mapViewModel.selectedListId {
                // Find the list from profileViewModel
                if let list = profileViewModel.lightweightPlaceLists.first(where: { $0.id == listId }),
                   let listIndex = profileViewModel.lightweightPlaceLists.firstIndex(where: { $0.id == listId }) {
                    BottomSheetView(
                        isPresented: $mapViewModel.showingListPopup,
                        sheetHeight: $sheetHeight,
                        minSheetHeight: minSheetHeight,
                        maxSheetHeight: maxSheetHeight
                    ) {
                        LightweightListPopupView(
                            lists: profileViewModel.lightweightPlaceLists,
                            initialListIndex: listIndex
                        )
                        .onDisappear {
                            // Clear list filter when popup is dismissed
                            mapViewModel.clearListFilter()
                            profileViewModel.selectedListIdForMap = nil
                        }
                    }
                }
            }
        }
    }
}
