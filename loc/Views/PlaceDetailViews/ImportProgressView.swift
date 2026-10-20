//
//  ImportProgressView.swift
//  loc
//
//  Live progress sheet for importing places from a shared video.
//

import SwiftUI

struct ImportProgressView: View {
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @StateObject private var viewModel: ImportProgressViewModel

    /// Creates the progress sheet for a shared content URL.
    init(contentUrl: String) {
        self._viewModel = StateObject(wrappedValue: ImportProgressViewModel(contentUrl: contentUrl))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            placeList
            footer
        }
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    /// Status line with a spinner while the import runs.
    private var header: some View {
        HStack(spacing: 12) {
            if !viewModel.isFinished {
                ProgressView()
            } else if viewModel.errorMessage != nil {
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
            } else {
                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
            }
            Text(viewModel.statusText)
                .font(.headline)
            Spacer()
        }
        .padding()
    }

    /// Places appearing one by one as the backend finds and saves them.
    private var placeList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding()
                }
                ForEach(viewModel.places) { item in
                    placeRow(item)
                    Divider().padding(.leading, 52)
                }
            }
            .animation(.easeInOut, value: viewModel.places.map { "\($0.index)\($0.status.rawValue)" })
        }
    }

    /// One row in the live list.
    private func placeRow(_ item: ImportJobPlace) -> some View {
        Button {
            if let place = item.place, viewModel.isFinished {
                viewModel.openConfirmation(for: place, detailPlaceVM: detailPlaceViewModel)
            }
        } label: {
            HStack(spacing: 12) {
                statusIcon(item.status)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.place?.name ?? item.name)
                        .font(.body)
                        .foregroundColor(.primary)
                    if let address = item.place?.address, !address.isEmpty {
                        Text(address)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    /// Icon for a place's save status.
    @ViewBuilder
    private func statusIcon(_ status: ImportJobPlaceStatus) -> some View {
        switch status {
        case .found:
            Image(systemName: "circle").foregroundColor(.secondary)
        case .saving:
            ProgressView().scaleEffect(0.8)
        case .saved, .duplicate:
            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill").foregroundColor(.red)
        }
    }

    /// Summary actions shown when the import finishes.
    private var footer: some View {
        VStack(spacing: 10) {
            if viewModel.isFinished && !viewModel.savedPlaces.isEmpty {
                Button {
                    viewModel.reviewAllPlaces(detailPlaceVM: detailPlaceViewModel)
                } label: {
                    Text(viewModel.savedPlaces.count == 1 ? "Open place" : "View \(viewModel.savedPlaces.count) places")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            Button(viewModel.isFinished ? "Done" : "Hide") {
                viewModel.dismiss()
            }
            .font(.subheadline)
        }
        .padding()
    }
}
