//
//  ImportProgressView.swift
//  loc
//
//  Live progress sheet for importing places from a shared video.
//

import SwiftUI

struct ImportProgressView: View {
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @EnvironmentObject var profile: ProfileViewModel
    @StateObject private var viewModel: ImportProgressViewModel
    @State private var showingManualAdd = false
    @State private var addAllConfirmation: String?
    @State private var confirmationDismissTask: Task<Void, Never>?

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
        .overlay(alignment: .top) { confirmationBanner }
        .onAppear {
            viewModel.start()
            profile.listsViewModel.ensureListsLoaded()
        }
        .onDisappear {
            viewModel.stop()
            confirmationDismissTask?.cancel()
        }
    }

    /// Toast shown after all places were added to a list.
    @ViewBuilder
    private var confirmationBanner: some View {
        if let message = addAllConfirmation {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                Text(message)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color(.systemBackground)).shadow(radius: 6))
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    /// Shows the add-all confirmation and hides it after a moment.
    @MainActor
    private func showAddAllConfirmation(_ message: String) {
        confirmationDismissTask?.cancel()
        withAnimation { addAllConfirmation = message }
        confirmationDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            withAnimation { addAllConfirmation = nil }
        }
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
                placeThumbnail(item.place)
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

    /// Small photo for a place, loaded from its photo URL once it has been saved.
    private func placeThumbnail(_ place: DetailPlace?) -> some View {
        AsyncImage(url: place?.photoUrls?.first.flatMap { URL(string: $0) }) { phase in
            if let image = phase.image {
                image.resizable().aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        Image(systemName: "fork.knife")
                            .font(.caption)
                            .foregroundColor(.gray)
                    )
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
                    Text(viewModel.savedPlaces.count == 1 ? "View & add to a list" : "View \(viewModel.savedPlaces.count) places & add to lists")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            if viewModel.isFinished {
                if viewModel.savedPlaces.isEmpty {
                    Button {
                        showingManualAdd = true
                    } label: {
                        Label("Add a place manually", systemImage: "magnifyingglass")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                } else {
                    Button {
                        showingManualAdd = true
                    } label: {
                        Label("Add another place", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
            Button(viewModel.isFinished ? "Done" : "Hide") {
                viewModel.dismiss()
            }
            .font(.subheadline)
        }
        .padding()
        .sheet(isPresented: $showingManualAdd) {
            // Reuses the existing search + assign flow; links the place to this video (external_places).
            PlaceCorrectionSheet(mode: .newAssignment(contentUrl: viewModel.contentUrl)) { place in
                detailPlaceViewModel.places[place.id.uuidString] = place
                viewModel.appendManualPlace(place)
                showAddAllConfirmation("Added \(place.name)")
            }
            .environmentObject(profile)
        }
    }
}
