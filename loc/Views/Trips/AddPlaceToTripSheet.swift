//
//  AddPlaceToTripSheet.swift
//  loc
//
//  Sheet container for adding places to a trip via browsing saved places or searching.
//

import SwiftUI

/// Sheet with segmented picker to browse saved places or search for new ones to add to a trip.
struct AddPlaceToTripSheet: View {
    let tripId: String
    let targetDayIndex: Int?
    let existingPlaceIds: Set<String>
    let userId: String
    let onDismiss: () -> Void

    @StateObject private var viewModel: AddPlaceToTripViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @Environment(\.dismiss) private var dismiss

    init(
        tripId: String,
        targetDayIndex: Int?,
        existingPlaceIds: Set<String>,
        userId: String,
        onDismiss: @escaping () -> Void
    ) {
        self.tripId = tripId
        self.targetDayIndex = targetDayIndex
        self.existingPlaceIds = existingPlaceIds
        self.userId = userId
        self.onDismiss = onDismiss
        self._viewModel = StateObject(wrappedValue: AddPlaceToTripViewModel(
            tripId: tripId,
            targetDayIndex: targetDayIndex,
            existingPlaceIds: existingPlaceIds,
            userId: userId
        ))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tabPicker
                tabContent
            }
            .navigationTitle("Add Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        onDismiss()
                        dismiss()
                    }
                }
            }
            .task {
                viewModel.onViewPlaceDetail = { [weak selectedPlaceVM, onDismiss] placeId in
                    selectedPlaceVM?.navigateToPlace(placeId: placeId)
                    onDismiss()
                    dismiss()
                }
                await viewModel.loadInitialData()
            }
        }
    }

    // MARK: - Tab Picker

    /// Segmented control to switch between browse and search tabs.
    private var tabPicker: some View {
        Picker("Mode", selection: $viewModel.selectedTab) {
            ForEach(AddPlaceToTripViewModel.Tab.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Tab Content

    /// Displays either the browse view or the search view based on the selected tab.
    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.selectedTab {
        case .browse:
            TripBrowsePlacesView(viewModel: viewModel)
        case .search:
            TripPlaceSearchContentView(viewModel: viewModel)
        }
    }
}
