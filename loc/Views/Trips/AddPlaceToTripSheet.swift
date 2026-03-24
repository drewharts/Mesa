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
    @StateObject private var viewModel: AddPlaceToTripViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @Environment(\.dismiss) private var dismiss

    init(
        tripId: String,
        targetDayIndex: Int?,
        existingPlaceIds: Set<String>,
        userId: String
    ) {
        self.tripId = tripId
        self.targetDayIndex = targetDayIndex
        self.existingPlaceIds = existingPlaceIds
        self.userId = userId
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
            .overlay(alignment: .bottom) {
                confirmationToast
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.confirmation)
            .navigationTitle("Add Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                viewModel.onViewPlaceDetail = { [weak selectedPlaceVM] placeId in
                    selectedPlaceVM?.navigateToPlace(placeId: placeId)
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

    // MARK: - Confirmation Toast

    /// Toast overlay showing add/remove confirmation, matching the ListSelectionSheet pattern.
    @ViewBuilder
    private var confirmationToast: some View {
        if let confirmation = viewModel.confirmation {
            let icon = confirmation.type == .removed ? "minus.circle.fill" : "checkmark.circle.fill"
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(confirmation.message)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color(.darkGray))
            )
            .padding(.bottom, 16)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .allowsHitTesting(false)
        }
    }
}
