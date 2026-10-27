//
//  ImportProgressView.swift
//  loc
//
//  Live progress sheet for importing places from a shared video.
//  When the import finishes, the found places and the user's lists are shown on this same screen:
//  a smart default list is preselected and a single tap saves everything (no second screen).
//

import SwiftUI

struct ImportProgressView: View {
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var userSession: UserSession
    @StateObject private var viewModel: ImportProgressViewModel
    @State private var showingManualAdd = false
    @State private var addAllConfirmation: String?
    @State private var confirmationDismissTask: Task<Void, Never>?

    // One-tap save state
    @State private var listViewModel: PlaceListSelectionViewModel?
    @State private var selectedListId: String?
    /// Places the user unchecked (only relevant when several places were found).
    @State private var excludedPlaceIds: Set<String> = []
    @State private var isSaving = false

    /// Creates the progress sheet for a shared content URL.
    init(contentUrl: String) {
        self._viewModel = StateObject(wrappedValue: ImportProgressViewModel(contentUrl: contentUrl))
    }

    /// Opens an existing import job (e.g. from a notification tap).
    init(jobId: String) {
        self._viewModel = StateObject(wrappedValue: ImportProgressViewModel(jobId: jobId))
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
        .onChange(of: viewModel.savedPlaces.count) { _, _ in
            // A place added by hand after an empty result still gets the one-tap save.
            if viewModel.isFinished && !viewModel.savedPlaces.isEmpty { prepareListChoices() }
        }
        .onChange(of: viewModel.isFinished) { _, finished in
            if finished && !viewModel.savedPlaces.isEmpty {
                refreshProfileAfterImport()
                prepareListChoices()
            }
        }
        .onDisappear {
            viewModel.stop()
            confirmationDismissTask?.cancel()
            refreshProfileAfterImport()
        }
    }

    /// Reloads the Videos tab, profile counts, and map pins so new imports appear.
    private func refreshProfileAfterImport() {
        profile.externalContentViewModel.refreshExternalPlacesAfterImport()
        profile.invalidateProfileCounts()
        profile.mapViewModel?.invalidateAnnotations()
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
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.statusText)
                    .font(.headline)
                if !viewModel.isFinished {
                    Text(viewModel.notificationsEnabled
                         ? "You can close this — we'll notify you when it's done."
                         : "Importing in the background…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
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
        HStack(spacing: 0) {
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
                .padding(.leading)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let place = item.place, showsSelectionToggles, item.status == .saved {
                let included = !excludedPlaceIds.contains(place.id.uuidString)
                Button {
                    if included { excludedPlaceIds.insert(place.id.uuidString) } else { excludedPlaceIds.remove(place.id.uuidString) }
                } label: {
                    Image(systemName: included ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundColor(included ? .accentColor : .secondary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(included ? "Included in save" : "Excluded from save")
            } else {
                Color.clear.frame(width: 16, height: 1)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    /// Per-place checkmarks only make sense once the import is done and there is a choice to make.
    private var showsSelectionToggles: Bool {
        viewModel.isFinished && viewModel.savedPlaces.count > 1
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

    // MARK: - One-tap save to a list

    /// Places that will be saved: everything found, minus anything the user unchecked.
    private var placesToSave: [DetailPlace] {
        viewModel.savedPlaces.filter { !excludedPlaceIds.contains($0.id.uuidString) }
    }

    private var selectedList: LightweightPlaceList? {
        listViewModel?.lists.first { $0.list_id == selectedListId }
    }

    /// Inline list choices (smart default preselected) and the single save button.
    @ViewBuilder
    private var saveSection: some View {
        if let listViewModel {
            ImportSaveSection(
                listViewModel: listViewModel,
                selectedListId: $selectedListId,
                isSaving: isSaving,
                canSave: canSave,
                buttonTitle: saveButtonTitle,
                onSave: saveToSelectedList,
                onChooseElsewhere: { viewModel.reviewAllPlaces(detailPlaceVM: detailPlaceViewModel) }
            )
        }
    }

    private var canSave: Bool {
        !isSaving && selectedList != nil && !placesToSave.isEmpty
    }

    private var saveButtonTitle: String {
        guard let name = selectedList?.name else { return "Save" }
        let count = placesToSave.count
        return count <= 1 ? "Save to \(name)" : "Save \(count) places to \(name)"
    }

    /// Loads the user's lists (last-used first, then nearest) and preselects the first one.
    private func prepareListChoices() {
        guard listViewModel == nil, let first = viewModel.savedPlaces.first else { return }
        let vm = PlaceListSelectionViewModel(profile: profile, userSession: userSession)
        vm.bulkPlaces = viewModel.savedPlaces
        listViewModel = vm
        Task { @MainActor in
            await vm.loadInitialLists(for: first)
            // Smart default: `lists` is sorted last-used list first, then by proximity to the places.
            let lastUsed = PlaceListSelectionViewModel.lastUsedListId
            selectedListId = vm.lists.first(where: { $0.list_id == lastUsed })?.list_id ?? vm.lists.first?.list_id
        }
    }

    /// The one tap: saves all (checked) places to the selected list, then closes the sheet.
    private func saveToSelectedList() {
        guard let listViewModel, let list = selectedList, canSave else { return }
        let places = placesToSave
        isSaving = true
        Task { @MainActor in
            let result = await listViewModel.addAllAndWait(places, to: list)
            isSaving = false
            Analytics.track(.importSavedToList, ["places": places.count, "added": result.added])
            let message = result.added == 0 && result.skipped > 0
                ? "Already in \(list.name)"
                : "Added \(result.added) place\(result.added == 1 ? "" : "s") to \(list.name)"
            showAddAllConfirmation(message)
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            viewModel.dismiss()
        }
    }

    /// Summary actions shown when the import finishes.
    private var footer: some View {
        VStack(spacing: 10) {
            if viewModel.isFinished && !viewModel.savedPlaces.isEmpty {
                saveSection
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
            Button(viewModel.isFinished ? (viewModel.savedPlaces.isEmpty ? "Done" : "Skip") : "Hide") {
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

/// Observes the list view model so chips appear as soon as the lists finish loading.
private struct ImportSaveSection: View {
    @ObservedObject var listViewModel: PlaceListSelectionViewModel
    @Binding var selectedListId: String?
    let isSaving: Bool
    let canSave: Bool
    let buttonTitle: String
    let onSave: () -> Void
    let onChooseElsewhere: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !listViewModel.lists.isEmpty {
                Text("Save to")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(listViewModel.lists, id: \.list_id) { list in
                            chip(list)
                        }
                    }
                }
                Button(action: onSave) {
                    HStack(spacing: 8) {
                        if isSaving { ProgressView().tint(.white) }
                        Text(buttonTitle)
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor.opacity(canSave ? 1 : 0.4))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!canSave)
            } else if listViewModel.isLoadingInitial {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .padding(.vertical, 8)
            } else {
                // No lists yet (or they failed to load): fall back to the full list picker.
                Button(action: onChooseElsewhere) {
                    Text("Choose a list")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
        }
    }

    private func chip(_ list: LightweightPlaceList) -> some View {
        let isSelected = list.list_id == selectedListId
        return Button {
            selectedListId = list.list_id
        } label: {
            HStack(spacing: 4) {
                if isSelected { Image(systemName: "checkmark").font(.caption.weight(.bold)) }
                Text(list.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(isSelected ? Color.accentColor : Color(.secondarySystemBackground)))
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}
