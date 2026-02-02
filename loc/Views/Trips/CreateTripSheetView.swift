//
//  CreateTripSheetView.swift
//  loc
//
//  Sheet view for creating a new trip with name and date selection.
//

import SwiftUI

/// Sheet for creating a new trip.
struct CreateTripSheetView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @Environment(\.dismiss) private var dismiss

    @StateObject private var viewModel: CreateTripViewModel

    /// Initializes the view with the profile's trips ViewModel.
    init() {
        // Note: tripsViewModel is set via environment, so we initialize with nil
        // and update on appear
        self._viewModel = StateObject(wrappedValue: CreateTripViewModel(tripsViewModel: nil))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                tripNameField
                dateSelectionSection
                Spacer()
                createButton
            }
            .padding(20)
            .navigationTitle("New Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingCalendar) {
                TripCalendarDatePicker(
                    startDate: $viewModel.startDate,
                    endDate: $viewModel.endDate
                )
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.clearError() }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .onAppear {
                viewModel.setTripsViewModel(profile.tripsViewModel)
            }
        }
    }

    /// Trip name input field.
    private var tripNameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Trip Name")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.gray)

            TextField("e.g., NYC Weekend", text: $viewModel.tripName)
                .font(.body)
                .padding(12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
        }
    }

    /// Date selection section with preview and button.
    private var dateSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dates")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.gray)

            Button(action: { viewModel.openCalendar() }) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)

                    Text(viewModel.formattedDateRange)
                        .foregroundColor(.black)

                    Spacer()

                    Text("\(viewModel.numberOfDays) days")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            }
        }
    }

    /// Create button.
    private var createButton: some View {
        Button {
            Task {
                if await viewModel.createTrip() {
                    dismiss()
                }
            }
        } label: {
            HStack {
                if viewModel.isCreating {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Create Trip")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(viewModel.canCreate ? Color.blue : Color.gray.opacity(0.3))
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!viewModel.canCreate || viewModel.isCreating)
    }
}
