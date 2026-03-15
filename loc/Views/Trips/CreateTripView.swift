//
//  CreateTripView.swift
//  loc
//
//  Top-level view for the trip creation wizard
//

import SwiftUI

/// Multi-step trip creation wizard that switches between steps.
struct CreateTripView: View {
    @EnvironmentObject var userSession: UserSession
    @StateObject private var viewModel = CreateTripViewModel()
    @Environment(\.dismiss) private var dismiss

    /// Called after successful trip creation with the new trip's ID.
    var onComplete: ((String) -> Void)?

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.currentStep {
                case .name:
                    TripNameStepView(viewModel: viewModel)
                case .dates:
                    TripDatesStepView(viewModel: viewModel)
                case .contributors:
                    TripContributorsStepView(viewModel: viewModel)
                case .creating:
                    TripCreatingView()
                case .completed(let tripId):
                    TripCompletedView(tripId: tripId) {
                        onComplete?(tripId)
                        dismiss()
                    }
                case .failed(let message):
                    TripFailedView(message: message) {
                        viewModel.currentStep = .name
                    }
                }
            }
            .navigationTitle("New Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if viewModel.currentStep == .name {
                        Button("Cancel") { dismiss() }
                    } else if canGoBack {
                        Button("Back") { viewModel.previousStep() }
                    }
                }
            }
        }
    }

    /// Whether the current step supports going back.
    private var canGoBack: Bool {
        switch viewModel.currentStep {
        case .dates, .contributors:
            return true
        default:
            return false
        }
    }
}
