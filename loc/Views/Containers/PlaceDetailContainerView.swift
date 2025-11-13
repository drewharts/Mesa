//
//  PlaceDetailContainerView.swift
//  loc
//
//  Created by Cursor on 11/13/25.
//

import SwiftUI

/// Container that manages place detail sheet presentation
struct PlaceDetailContainerView: View {
    @EnvironmentObject var appCoordinator: AppCoordinator
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    @EnvironmentObject var notificationManager: NotificationManager
    
    let profileViewModel: ProfileViewModel
    let detailPlaceViewModel: DetailPlaceViewModel
    let serviceContainer: ServiceContainer
    
    @Binding var sheetHeight: CGFloat
    let minSheetHeight: CGFloat
    let maxSheetHeight: CGFloat
    
    var body: some View {
        Group {
            if selectedPlaceVM.isDetailSheetPresented {
                BottomSheetView(
                    isPresented: $selectedPlaceVM.isDetailSheetPresented,
                    sheetHeight: $sheetHeight,
                    minSheetHeight: minSheetHeight,
                    maxSheetHeight: maxSheetHeight
                ) {
                    PlaceDetailView(
                        sheetHeight: $sheetHeight,
                        minSheetHeight: minSheetHeight
                    )
                    .environmentObject(userProfileViewModel)
                    .environmentObject(notificationManager)
                    .environmentObject(profileViewModel)
                    .environmentObject(detailPlaceViewModel)
                    .environmentObject(serviceContainer)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

