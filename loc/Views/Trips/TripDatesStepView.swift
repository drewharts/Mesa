//
//  TripDatesStepView.swift
//  loc
//
//  Second step of trip creation - select arrival/departure dates
//

import SwiftUI

/// Date picker step for selecting trip start and end dates.
struct TripDatesStepView: View {
    @ObservedObject var viewModel: CreateTripViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "calendar")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("When are you going?")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(spacing: 16) {
                DatePicker(
                    "Arrive",
                    selection: $viewModel.startDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)

                DatePicker(
                    "Depart",
                    selection: $viewModel.endDate,
                    in: viewModel.startDate...,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
            }
            .padding(.horizontal, 32)

            Text("\(viewModel.endDate >= viewModel.startDate ? dayCount : 0) day\(dayCount == 1 ? "" : "s")")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                viewModel.nextStep()
            } label: {
                Text("Next")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.canProceed ? Color.accentColor : Color.gray.opacity(0.3))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!viewModel.canProceed)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    /// Computes the inclusive day count for the selected range.
    private var dayCount: Int {
        let days = Calendar.current.dateComponents([.day], from: viewModel.startDate, to: viewModel.endDate).day ?? 0
        return days + 1
    }
}
