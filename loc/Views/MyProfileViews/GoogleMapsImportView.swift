//
//  GoogleMapsImportView.swift
//  loc
//
//  DUMB Component: Sheet for importing places from a shared Google Maps list URL
//  Single Responsibility: Render import flow UI based on ViewModel state
//
//  States: URL entry -> Extracting -> Resolving places -> Preview results -> Creating list -> Completed / Failed
//  Contains no business logic — all state managed by GoogleMapsImportViewModel
//

import SwiftUI

struct GoogleMapsImportView: View {
    @StateObject private var viewModel = GoogleMapsImportViewModel()
    @Environment(\.dismiss) private var dismiss

    let userId: String
    let existingLists: [LightweightPlaceList]
    var onImportCompleted: ((_ listId: String) -> Void)?

    @State private var useExistingList = false
    @State private var selectedExistingListId: String? = nil

    private let cornerRadius: CGFloat = 12

    // MARK: - Body

    var body: some View {
        NavigationView {
            Group {
                switch viewModel.importState {
                case .idle:
                    if !viewModel.resolvedPlaces.isEmpty {
                        previewResultsView
                    } else {
                        urlEntryView
                    }
                case .extracting:
                    extractingView
                case .resolvingPlaces:
                    resolvingPlacesView
                case .creatingList, .addingPlaces:
                    creatingListView
                case .completed:
                    completedView
                case .failed:
                    failedView
                }
            }
            .navigationTitle("Import from Google Maps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - URL Entry

    private var urlEntryView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Instructions
            Text("Paste a shared Google Maps list URL to import all its places into Mesa.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.top, 8)

            // URL text field
            VStack(alignment: .leading, spacing: 8) {
                Text("List URL")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                TextField("https://maps.app.goo.gl/...", text: $viewModel.url)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(14)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
            }
            .padding(.horizontal)

            // Extract button
            Button {
                Task { await viewModel.extractPlaces() }
            } label: {
                Text("Extract Places")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .padding(.horizontal)

            Text("Works with shared list links.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Spacer()
        }
    }

    // MARK: - Extracting

    private var extractingView: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
                .scaleEffect(0.8)
            Text("Extracting places from Google Maps...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    // MARK: - Resolving Places (Phase 2 Progress)

    private var resolvingPlacesView: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
                .scaleEffect(0.8)

            if case .resolvingPlaces(let current, let total) = viewModel.importState {
                Text("Resolving place \(current) of \(total)...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ProgressView(value: Double(current), total: Double(total))
                    .padding(.horizontal, 48)
            }

            Spacer()
        }
    }

    // MARK: - Preview Results

    private var previewResultsView: some View {
        VStack(spacing: 0) {
            // Summary
            HStack {
                Label("\(viewModel.resolvedPlaces.count) places found", systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Spacer()
                if !viewModel.resolveErrors.isEmpty {
                    Text("\(viewModel.resolveErrors.count) unresolved")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)

            // Segmented picker: Create New vs Add to Existing
            Picker("", selection: $useExistingList) {
                Text("Create New List").tag(false)
                Text("Add to Existing").tag(true)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 12)

            // Destination section
            if useExistingList {
                existingListSelectionView
            } else {
                newListNameField
            }

            // Place list
            placeListView

            // Action button
            actionButton
        }
    }

    // MARK: - New List Name Field

    /// Displays an editable text field for naming a new list.
    private var newListNameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("List Name")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            TextField("Enter list name", text: $viewModel.listName)
                .padding(14)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
        }
        .padding(.horizontal)
        .padding(.top, 12)
    }

    // MARK: - Existing List Selection

    /// Displays a scrollable list of the user's existing lists for selection, or an empty state.
    private var existingListSelectionView: some View {
        Group {
            if existingLists.isEmpty {
                existingListEmptyState
            } else {
                existingListPicker
            }
        }
    }

    /// Displays a message when the user has no existing lists to import into.
    private var existingListEmptyState: some View {
        VStack(spacing: 8) {
            Text("No existing lists")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Create a list first, then import places to it.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    /// Displays a scrollable picker of the user's existing lists with single-selection checkmark.
    private var existingListPicker: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(existingLists) { list in
                    Button {
                        selectedExistingListId = list.list_id
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(list.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                Text("\(list.place_count) places")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if selectedExistingListId == list.list_id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                        .background(
                            selectedExistingListId == list.list_id
                                ? Color.accentColor.opacity(0.08)
                                : Color.clear
                        )
                    }
                    Divider().padding(.leading)
                }
            }
        }
        .frame(maxHeight: 160)
        .padding(.top, 8)
    }

    // MARK: - Place List

    /// Displays the list of resolved places and any unresolved errors.
    private var placeListView: some View {
        List {
            ForEach(viewModel.resolvedPlaces) { place in
                VStack(alignment: .leading, spacing: 2) {
                    Text(place.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if !place.address.isEmpty {
                        Text(place.address)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            if !viewModel.resolveErrors.isEmpty {
                Section("Could not resolve") {
                    ForEach(viewModel.resolveErrors, id: \.self) { error in
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Action Button

    /// Displays the primary action button that creates a new list or adds places to an existing one.
    private var actionButton: some View {
        Button {
            Task {
                if useExistingList, let listId = selectedExistingListId,
                   let list = existingLists.first(where: { $0.list_id == listId }) {
                    await viewModel.addPlacesToExistingList(
                        listId: listId, listName: list.name, userId: userId
                    )
                } else {
                    await viewModel.createListWithPlaces(userId: userId)
                }
            }
        } label: {
            Text(useExistingList ? "Add Places" : "Create List")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .disabled(actionButtonDisabled)
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    /// Returns whether the action button should be disabled based on current mode.
    private var actionButtonDisabled: Bool {
        if useExistingList {
            return selectedExistingListId == nil
        } else {
            return viewModel.listName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    // MARK: - Creating List

    private var creatingListView: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
                .scaleEffect(0.8)

            if case .addingPlaces(let current, let total) = viewModel.importState {
                Text("Adding place \(current) of \(total)...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ProgressView(value: Double(current), total: Double(total))
                    .padding(.horizontal, 48)
            } else {
                Text(useExistingList ? "Adding places..." : "Creating list...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Completed

    private var completedView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)

            Text(useExistingList ? "Places Added!" : "List Created!")
                .font(.title3)
                .fontWeight(.semibold)

            Text("\(viewModel.resolvedPlaces.count) places added to \"\(viewModel.listName)\"")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                if case .completed(let listId) = viewModel.importState {
                    onImportCompleted?(listId)
                }
                dismiss()
            } label: {
                Text("Done")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)

            Spacer()
        }
    }

    // MARK: - Failed

    private var failedView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Import Failed")
                .font(.title3)
                .fontWeight(.semibold)

            if case .failed(let message) = viewModel.importState {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button {
                viewModel.reset()
            } label: {
                Text("Try Again")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)

            Spacer()
        }
    }
}
