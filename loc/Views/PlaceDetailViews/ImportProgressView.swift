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
    @State private var showingAddAllToList = false
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
        .sheet(isPresented: $showingAddAllToList) {
            ImportAddAllToListSheet(
                places: viewModel.savedPlaces,
                listsVM: profile.listsViewModel,
                onAdded: { message in showAddAllConfirmation(message) }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
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
                    Text(viewModel.savedPlaces.count == 1 ? "Open place" : "View \(viewModel.savedPlaces.count) places")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            if viewModel.isFinished && !viewModel.savedPlaces.isEmpty {
                Button {
                    showingAddAllToList = true
                } label: {
                    Label(viewModel.savedPlaces.count == 1 ? "Add to a list" : "Add all \(viewModel.savedPlaces.count) to a list",
                          systemImage: "text.badge.plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
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

/// Picker that adds every imported place to one existing or new list.
struct ImportAddAllToListSheet: View {
    let places: [DetailPlace]
    @ObservedObject var listsVM: ProfileListsViewModel
    let onAdded: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showingNewList = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            List {
                Section {
                    Button {
                        showingNewList = true
                    } label: {
                        Label("New list", systemImage: "plus.circle.fill")
                            .font(.body.weight(.semibold))
                    }
                }
                Section(header: Text("Your lists")) {
                    if listsVM.lightweightPlaceLists.isEmpty {
                        Text("No lists yet. Create one above.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    ForEach(listsVM.lightweightPlaceLists, id: \.list_id) { list in
                        Button {
                            addAll(toListId: list.list_id, listName: list.name)
                        } label: {
                            HStack {
                                Text(list.name)
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("\(listsVM.lightweightPlaceListCounts[list.list_id] ?? list.place_count)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                }
            }
            .navigationTitle(places.count == 1 ? "Add to list" : "Add \(places.count) places")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear { listsVM.ensureListsLoaded() }
        .sheet(isPresented: $showingNewList) {
            NewListSheetView(onSave: { listName in
                let result = await listsVM.addNewPlaceList(named: listName, city: "", emoji: "", image: "")
                switch result {
                case .success(let createdList):
                    // Let the new-list sheet finish dismissing before closing this one.
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    await MainActor.run {
                        addAll(toListId: createdList.id.uuidString, listName: createdList.name)
                    }
                case .failure(let error):
                    await MainActor.run { errorMessage = error.localizedDescription }
                }
            })
            .presentationDetents([.height(200)])
            .presentationDragIndicator(.visible)
        }
    }

    /// Adds every place not already in the list, then reports back and closes.
    @MainActor
    private func addAll(toListId listId: String, listName: String) {
        let existing = Set((listsVM.lightweightPlaceListPlaces[listId] ?? []).map { $0.place_id })
        let toAdd = places.filter { !existing.contains($0.id.uuidString) }
        for place in toAdd {
            listsVM.addPlaceToLightweightList(listId: listId, place: place)
        }
        let skipped = places.count - toAdd.count
        var message = "Added \(toAdd.count) place\(toAdd.count == 1 ? "" : "s") to \(listName)"
        if skipped > 0 {
            message += " (\(skipped) already there)"
        }
        onAdded(message)
        dismiss()
    }
}
