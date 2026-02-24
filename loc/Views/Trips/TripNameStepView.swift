//
//  TripNameStepView.swift
//  loc
//
//  First step of trip creation - enter trip name
//

import SwiftUI

/// Text field step for entering the trip name.
struct TripNameStepView: View {
    @ObservedObject var viewModel: CreateTripViewModel
    @FocusState private var isNameFocused: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "airplane.departure")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("What's your trip called?")
                .font(.title2)
                .fontWeight(.semibold)

            TextField("e.g. Tokyo Spring 2026", text: $viewModel.tripName)
                .font(.title3)
                .multilineTextAlignment(.center)
                .textFieldStyle(.plain)
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 32)
                .focused($isNameFocused)
                .submitLabel(.next)
                .onSubmit {
                    if viewModel.canProceed {
                        viewModel.nextStep()
                    }
                }

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
        .onAppear { isNameFocused = true }
    }
}
