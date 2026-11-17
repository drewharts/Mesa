//
//  ListSheetLoadView.swift
//  loc
//
//  Placeholder shown while a list that isn't cached yet is fetched; shows an error with retry on failure.
//

import SwiftUI

struct ListSheetLoadView: View {
    @StateObject private var viewModel: ListSheetLoadViewModel

    /// Creates the placeholder around a loader that fetches the missing list.
    init(viewModel: ListSheetLoadViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 12) {
            switch viewModel.state {
            case .loading:
                ProgressView()
                    .padding()
                Text("Loading list...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            case .failed(let message):
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Button("Try again") {
                    Task { await viewModel.load() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await viewModel.load() }
    }
}
