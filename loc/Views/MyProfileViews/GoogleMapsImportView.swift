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
    var cancelLabel: String = "Cancel"
    var onCancel: (() -> Void)? = nil

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
                    Button(cancelLabel) {
                        if let onCancel {
                            onCancel()
                        } else {
                            dismiss()
                        }
                    }
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
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    summaryCard
                    modeToggle

                    if useExistingList {
                        existingListSelectionView
                    } else {
                        newListNameField
                    }

                    placeListView
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }

            Divider()
            actionButton
        }
    }

    // MARK: - Summary Card

    /// Displays a summary card showing the number of resolved places and any errors.
    private var summaryCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.accentColor)
                .frame(width: 40, height: 40)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.resolvedPlaces.count) places found")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("Ready to import")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !viewModel.resolveErrors.isEmpty {
                Text("\(viewModel.resolveErrors.count) !")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .padding(14)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    // MARK: - Mode Toggle

    /// Displays capsule pill buttons for toggling between create-new and add-to-existing modes.
    private var modeToggle: some View {
        HStack(spacing: 8) {
            NearbyFilterButton(title: "Create New List", isSelected: !useExistingList) {
                withAnimation(.easeInOut(duration: 0.2)) { useExistingList = false }
            }
            NearbyFilterButton(title: "Add to Existing", isSelected: useExistingList) {
                withAnimation(.easeInOut(duration: 0.2)) { useExistingList = true }
            }
        }
    }

    // MARK: - New List Name Field

    /// Displays an editable text field for naming a new list.
    private var newListNameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("List Name")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            TextField("Enter list name", text: $viewModel.listName)
                .padding(14)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
        }
    }

    // MARK: - Existing List Selection

    /// Displays a scrollable list of the user's existing lists for selection, or an empty state.
    private var existingListSelectionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Choose a List")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

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
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    /// Displays a scrollable picker of the user's existing lists with single-selection indicators.
    private var existingListPicker: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(existingLists.enumerated()), id: \.element.id) { index, list in
                    Button {
                        selectedExistingListId = list.list_id
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .frame(width: 28, height: 28)
                                .background(Color(.systemGray5))
                                .clipShape(RoundedRectangle(cornerRadius: 6))

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

                            Image(systemName: selectedExistingListId == list.list_id
                                  ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedExistingListId == list.list_id
                                                 ? .accentColor : Color(.systemGray3))
                                .font(.system(size: 20))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            selectedExistingListId == list.list_id
                                ? Color.accentColor.opacity(0.06)
                                : Color.clear
                        )
                    }
                    .buttonStyle(.plain)

                    if index < existingLists.count - 1 {
                        Divider().padding(.leading, 52)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxHeight: 200)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    // MARK: - Place List

    /// Displays the resolved places and any unresolved errors in a card-styled list.
    private var placeListView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Places")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            LazyVStack(spacing: 0) {
                ForEach(Array(viewModel.resolvedPlaces.enumerated()), id: \.element.id) { index, place in
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.accentColor)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(place.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            if !place.address.isEmpty {
                                Text(place.address)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)

                    if index < viewModel.resolvedPlaces.count - 1 || !viewModel.resolveErrors.isEmpty {
                        Divider().padding(.leading, 44)
                    }
                }

                if !viewModel.resolveErrors.isEmpty {
                    unresolvedErrorsSection
                }
            }
            .padding(.vertical, 4)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
    }

    /// Displays the unresolved place errors at the bottom of the places card.
    private var unresolvedErrorsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.orange)
                Text("Could not resolve (\(viewModel.resolveErrors.count))")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            ForEach(viewModel.resolveErrors, id: \.self) { error in
                Text(error)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: - Action Button

    /// Displays the primary sticky action button that creates a new list or adds places to an existing one.
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
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Color(.systemBackground))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    Capsule().fill(Color.primary)
                )
        }
        .buttonStyle(.plain)
        .disabled(actionButtonDisabled)
        .opacity(actionButtonDisabled ? 0.3 : 1.0)
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
