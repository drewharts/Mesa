//
//  TripDatesStepView.swift
//  loc
//
//  Second step of trip creation - select arrival/departure dates via inline calendar
//

import SwiftUI

/// Date picker step for selecting trip start and end dates using an inline calendar range picker.
struct TripDatesStepView: View {
    @ObservedObject var viewModel: CreateTripViewModel

    private let mesaCharcoal = Color(red: 45/255, green: 45/255, blue: 45/255)

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar")
                .font(.system(size: 48))
                .foregroundColor(mesaCharcoal)

            Text("When are you going?")
                .font(.title2)
                .fontWeight(.semibold)

            DateRangeCalendarView(viewModel: viewModel.dateRangePickerViewModel)

            dayCountLabel

            Spacer()

            Button {
                viewModel.nextStep()
            } label: {
                Text("Next")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        Capsule().fill(viewModel.canProceed ? mesaCharcoal : mesaCharcoal.opacity(0.4))
                    )
            }
            .disabled(!viewModel.canProceed)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Day Count Label

    private var dayCountLabel: some View {
        Group {
            if case .complete = viewModel.dateRangePickerViewModel.selectionState {
                Text("\(dayCount) day\(dayCount == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if case .startOnly = viewModel.dateRangePickerViewModel.selectionState {
                Text("Select an end date")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Tap a start date")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Computes the inclusive day count for the selected range.
    private var dayCount: Int {
        let days = Calendar.current.dateComponents([.day], from: viewModel.startDate, to: viewModel.endDate).day ?? 0
        return days + 1
    }
}
