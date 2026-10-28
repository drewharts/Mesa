//
//  ImportProgressView.swift
//  loc
//
//  Live progress sheet for importing places from a shared video.
//  When the import finishes, the found places and the user's lists are shown on this same screen:
//  search or create a list, pick it, one tap saves everything. Each place has a "Wrong?" fix.
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
    /// Detected place the user flagged as wrong (opens the place search to replace it).
    @State private var correctingPlace: DetailPlace?

    /// Creates the progress sheet for a shared content URL.
    init(contentUrl: String) {
        self._viewModel = StateObject(wrappedValue: ImportProgressViewModel(contentUrl: contentUrl))
    }

    /// Opens an existing import job (e.g. from a notification tap).
    init(jobId: String) {
        self._viewModel = StateObject(wrappedValue: ImportProgressViewModel(jobId: jobId))
    }

    var body: some View { analyticsBody.analyticsScreen("Import Sheet") }

    @ViewBuilder private var analyticsBody: some View {
        // One continuous sheet: a single scroll on the sheet's material (no opaque panel, no divider),
        // with the primary button pinned at the bottom on the same material behind a soft fade.
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                placeList
                saveSection
            }
            .padding(.bottom, 12)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
        .background(Color.clear)
        .presentationBackground(.regularMaterial)
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
                Image(systemName: "mappin.circle.fill").foregroundColor(.accentColor)
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
        Group {
            VStack(alignment: .leading, spacing: 0) {
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding()
                }
                ForEach(viewModel.places) { item in
                    placeRow(item)
                }
                if viewModel.isFinished && !viewModel.savedPlaces.isEmpty {
                    Button { showingManualAdd = true } label: {
                        Label("Add a place the video missed", systemImage: "plus")
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
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
                            .lineLimit(1)
                        if let address = item.place?.address, !address.isEmpty {
                            Text(address)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 4)
                }
                .padding(.leading)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let place = item.place, viewModel.isFinished, item.status == .saved || item.status == .duplicate {
                // "Wrong place?": pick the right one (search) or drop it from this import.
                Menu {
                    Button {
                        correctingPlace = place
                    } label: {
                        Label("Pick the right place", systemImage: "magnifyingglass")
                    }
                    Button(role: .destructive) {
                        Task { await viewModel.removePlace(place) }
                    } label: {
                        Label("Remove from this video", systemImage: "trash")
                    }
                } label: {
                    Text("Wrong?")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color(.secondarySystemBackground)))
                }
                .accessibilityLabel("Wrong place? Fix \(place.name)")
            }

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
            // Found and linked to the video; not in a list yet.
            Image(systemName: "mappin.circle.fill").foregroundColor(.accentColor)
        case .failed:
            Image(systemName: "xmark.circle.fill").foregroundColor(.red)
        }
    }

    // MARK: - Save to a list

    /// Places that will be saved: everything found, minus anything unchecked, never a placeholder id.
    private var placesToSave: [DetailPlace] {
        viewModel.savedPlaces.filter {
            !excludedPlaceIds.contains($0.id.uuidString) && !PlaceIdGuard.isPlaceholder($0.id.uuidString)
        }
    }

    /// Loads every list (owned + shared, last-used first). Nothing is preselected: the user picks.
    private func prepareListChoices() {
        guard listViewModel == nil, let first = viewModel.savedPlaces.first else { return }
        let vm = PlaceListSelectionViewModel(profile: profile, userSession: userSession)
        vm.bulkPlaces = viewModel.savedPlaces
        listViewModel = vm
        Task { @MainActor in await vm.loadInitialLists(for: first) }
    }

    /// Saves all (checked) places to the given list, then closes the sheet.
    private func saveToList(_ list: LightweightPlaceList) {
        guard let listViewModel, !isSaving, !placesToSave.isEmpty else { return }
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

    /// Inline "Save to list" section in the same scroll: header, search (picks or creates), recent lists.
    @ViewBuilder
    private var saveSection: some View {
        if viewModel.isFinished && !viewModel.savedPlaces.isEmpty, let listViewModel {
            ImportSaveSection(listViewModel: listViewModel, selectedListId: $selectedListId)
                .padding(.horizontal)
                .padding(.top, 16)
        }
    }

    /// Pinned bottom action on the sheet's material with a soft top fade (no hard edge).
    private var footer: some View {
        VStack(spacing: 10) {
            if viewModel.isFinished && !viewModel.savedPlaces.isEmpty, let listViewModel {
                ImportSaveButton(
                    listViewModel: listViewModel,
                    selectedListId: selectedListId,
                    isSaving: isSaving,
                    placeCount: placesToSave.count,
                    onSave: { list in saveToList(list) }
                )
            } else if viewModel.isFinished {
                Button {
                    showingManualAdd = true
                } label: {
                    Label("Search for the place", systemImage: "magnifyingglass")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            } else {
                Button("Hide") { viewModel.dismiss() }
                    .font(.subheadline)
            }
        }
        .padding(.horizontal)
        .padding(.top, 20)
        .padding(.bottom, 8)
        .background(
            Rectangle()
                .fill(.regularMaterial)
                .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.35)],
                                     startPoint: .top, endPoint: .bottom))
                .ignoresSafeArea(edges: .bottom)
        )
        .sheet(isPresented: $showingManualAdd) {
            // Search + assign flow; links the place to this video (external_places) with a resolved id.
            PlaceCorrectionSheet(mode: .newAssignment(contentUrl: viewModel.contentUrl)) { place in
                guard !PlaceIdGuard.isPlaceholder(place.id.uuidString) else { return }
                detailPlaceViewModel.places[place.id.uuidString] = place
                viewModel.appendManualPlace(place)
                showAddAllConfirmation("Added \(place.name)")
            }
            .environmentObject(profile)
        }
        .sheet(item: $correctingPlace) { wrong in
            // Wrong place: search the right one; it is linked to the video, then the wrong link is removed.
            PlaceCorrectionSheet(mode: .newAssignment(contentUrl: viewModel.contentUrl)) { place in
                guard !PlaceIdGuard.isPlaceholder(place.id.uuidString) else { return }
                detailPlaceViewModel.places[place.id.uuidString] = place
                excludedPlaceIds.remove(wrong.id.uuidString)
                Task { await viewModel.replacePlace(wrong, with: place) }
                showAddAllConfirmation("Changed to \(place.name)")
            }
            .environmentObject(profile)
        }
    }
}

/// Resolves the selected list from the selection view model.
@MainActor
private func importSelectedList(_ vm: PlaceListSelectionViewModel, _ id: String?) -> LightweightPlaceList? {
    guard let id else { return nil }
    return vm.allLists.first { $0.list_id == id }
        ?? vm.lists.first { $0.list_id == id }
        ?? vm.filteredLists.first { $0.list_id == id }
}

/// Pinned primary button. Disabled copy stays "Pick a list to save to".
private struct ImportSaveButton: View {
    @ObservedObject var listViewModel: PlaceListSelectionViewModel
    let selectedListId: String?
    let isSaving: Bool
    let placeCount: Int
    let onSave: (LightweightPlaceList) -> Void

    private var selectedList: LightweightPlaceList? { importSelectedList(listViewModel, selectedListId) }
    private var canSave: Bool { !isSaving && selectedList != nil && placeCount > 0 }

    private var buttonTitle: String {
        guard let name = selectedList?.name else {
            return placeCount <= 1 ? "Pick a list to save to" : "Pick a list for \(placeCount) places"
        }
        return placeCount <= 1 ? "Add to \(name)" : "Add \(placeCount) places to \(name)"
    }

    var body: some View {
        Button { if let list = selectedList { onSave(list) } } label: {
            HStack(spacing: 8) {
                if isSaving { ProgressView().tint(.white) }
                Text(buttonTitle).font(.headline).lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor.opacity(canSave ? 1 : 0.35))
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!canSave)
    }
}

/// "Save to list": section header, the app's capsule search (type to find or create a list),
/// then every list inline (owned + shared, most recently used first). Nothing preselected.
private struct ImportSaveSection: View {
    @ObservedObject var listViewModel: PlaceListSelectionViewModel
    @Binding var selectedListId: String?

    @State private var query = ""
    @State private var isCreating = false
    @FocusState private var searchFocused: Bool

    private var sourceLists: [LightweightPlaceList] {
        listViewModel.allLists.isEmpty ? listViewModel.lists : listViewModel.allLists
    }

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespaces) }

    private var visibleLists: [LightweightPlaceList] {
        guard !trimmedQuery.isEmpty else { return sourceLists }
        return sourceLists.filter { $0.name.range(of: trimmedQuery, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }

    private var hasExactMatch: Bool {
        sourceLists.contains { $0.name.compare(trimmedQuery, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Save to list")
                    .font(.headline)
                Text("Search to pick a list, or type a new name to create one")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            searchField
            if listViewModel.isLoadingInitial && sourceLists.isEmpty {
                HStack { Spacer(); ProgressView(); Spacer() }.padding(.vertical, 10)
            } else {
                LazyVStack(spacing: 0) {
                    if !trimmedQuery.isEmpty && !hasExactMatch {
                        createRow(named: trimmedQuery)
                    }
                    if trimmedQuery.isEmpty && !sourceLists.isEmpty {
                        Text("Recent")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(visibleLists, id: \.list_id) { list in
                        row(list)
                    }
                    if trimmedQuery.isEmpty && sourceLists.isEmpty {
                        Text("No lists yet. Type a name above to create one.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    }
                }
            }
        }
    }

    /// Same capsule style as the app's other search fields (map "Search places...", lists search).
    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .font(.system(size: 14))
            TextField("Search or create a list", text: $query)
                .font(.subheadline)
                .focused($searchFocused)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit {
                    // Return picks the only match, or creates the list when none match.
                    if visibleLists.count == 1 { selectedListId = visibleLists[0].list_id }
                    else if visibleLists.isEmpty, !trimmedQuery.isEmpty { create(named: trimmedQuery) }
                }
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Capsule().fill(Color(.systemGray5).opacity(0.6)))
    }

    /// "Create “name”" row shown while typing a name that doesn't exist.
    private func createRow(named name: String) -> some View {
        Button { create(named: name) } label: {
            HStack(spacing: 10) {
                if isCreating { ProgressView().frame(width: 20) }
                else { Image(systemName: "plus.circle.fill").foregroundColor(.accentColor).frame(width: 20) }
                Text("Create \u{201C}\(name)\u{201D}")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.accentColor)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isCreating)
    }

    private func create(named name: String) {
        guard !isCreating else { return }
        isCreating = true
        Task { @MainActor in
            let result = await listViewModel.addNewListToSelection(named: name, city: "", emoji: "", image: "")
            isCreating = false
            if case .success = result {
                query = ""
                searchFocused = false
                selectedListId = listViewModel.allLists.first?.list_id ?? listViewModel.lists.first?.list_id
            }
        }
    }

    private func row(_ list: LightweightPlaceList) -> some View {
        let isSelected = list.list_id == selectedListId
        return Button {
            selectedListId = isSelected ? nil : list.list_id
            searchFocused = false
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .frame(width: 20)
                Text(list.name)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                if list.isCollaborative {
                    Image(systemName: "person.2.fill").font(.caption2).foregroundColor(.secondary)
                }
                Spacer()
                Text("\(list.place_count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
