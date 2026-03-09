//
//  ImportPlaceConfirmationViewModel.swift
//  loc
//
//  ViewModel for the post-import place confirmation prompt.
//  Single Responsibility: Manages confirm/reject/dismiss logic for an imported place.
//

import Foundation

@MainActor
class ImportPlaceConfirmationViewModel: ObservableObject {
    let place: DetailPlace
    let contentUrl: String

    @Published var showingCorrectionSheet: Bool = false

    /// Initializes with the detected place and the content URL that triggered the import.
    init(place: DetailPlace, contentUrl: String) {
        self.place = place
        self.contentUrl = contentUrl
    }

    /// Confirms the detected place, registers the user as a saver, and navigates to place detail.
    func confirmPlace(selectedPlaceVM: SelectedPlaceViewModel, detailPlaceVM: DetailPlaceViewModel) {
        registerUserAsSaver(in: detailPlaceVM)
        PresentationService.shared.dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            selectedPlaceVM.selectPlaceAndFetchDetails(self.place, shouldAnimateMap: true)
            selectedPlaceVM.isDetailSheetPresented = true
        }
    }

    /// Rejects the detected place and opens the correction sheet.
    func rejectPlace() {
        showingCorrectionSheet = true
    }

    /// Dismisses the confirmation sheet without any navigation.
    func dismissSheet() {
        PresentationService.shared.dismiss()
    }

    /// Handles completion of the correction flow by navigating to the corrected place.
    func handleCorrectionComplete(_ correctedPlace: DetailPlace, selectedPlaceVM: SelectedPlaceViewModel) {
        PresentationService.shared.dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            selectedPlaceVM.selectPlaceAndFetchDetails(correctedPlace, shouldAnimateMap: true)
            selectedPlaceVM.isDetailSheetPresented = true
        }
    }

    /// Registers the current user as a saver for the confirmed place.
    private func registerUserAsSaver(in detailPlaceVM: DetailPlaceViewModel) {
        Task {
            if let uid = await SupabaseAuthService.shared.currentUserId {
                await MainActor.run {
                    detailPlaceVM.placeSavers[self.place.id.uuidString] = [uid]
                }
            }
        }
    }
}
