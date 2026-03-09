//
//  ImportPlaceConfirmationView.swift
//  loc
//
//  Confirmation prompt shown after a TikTok import detects a single place.
//  Asks the user if the detected place is correct before navigating.
//

import SwiftUI

struct ImportPlaceConfirmationView: View {
    @StateObject private var viewModel: ImportPlaceConfirmationViewModel
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel

    init(place: DetailPlace, contentUrl: String) {
        self._viewModel = StateObject(wrappedValue: ImportPlaceConfirmationViewModel(place: place, contentUrl: contentUrl))
    }

    var body: some View {
        VStack(spacing: 0) {
            dragIndicator
            Spacer().frame(height: 24)
            headerSection
            Spacer().frame(height: 24)
            actionButtons
            Spacer()
        }
        .sheet(isPresented: $viewModel.showingCorrectionSheet) {
            PlaceCorrectionSheet(
                mode: .newAssignment(contentUrl: viewModel.contentUrl),
                onPlaceChanged: { place in
                    viewModel.handleCorrectionComplete(place, selectedPlaceVM: selectedPlaceVM)
                }
            )
            .environmentObject(profile)
        }
    }

    /// Displays a drag indicator at the top of the sheet.
    private var dragIndicator: some View {
        RoundedRectangle(cornerRadius: 2.5)
            .fill(Color(.systemGray4))
            .frame(width: 36, height: 5)
            .padding(.top, 8)
    }

    /// Displays the place info header with confirmation prompt.
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(.green)

            VStack(spacing: 6) {
                Text(viewModel.place.name)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)

                if let address = viewModel.place.address, !address.isEmpty {
                    Text(address)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                Text("Is this the right place?")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 20)
    }

    /// Displays the confirm, reject, and dismiss action buttons.
    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button(action: {
                viewModel.confirmPlace(selectedPlaceVM: selectedPlaceVM, detailPlaceVM: detailPlaceViewModel)
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .medium))
                    Text("Yes")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.green)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)

            Button(action: {
                viewModel.rejectPlace()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .medium))
                    Text("No, find correct place")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(.systemGray5))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)

            Button(action: {
                viewModel.dismissSheet()
            }) {
                Text("Dismiss")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(.horizontal, 20)
    }
}
