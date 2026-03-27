//
//  CategoryCorrectionSheet.swift
//  loc
//
//  Searchable grouped picker for correcting a place's category.
//

import SwiftUI

struct CategoryCorrectionSheet: View {
    @StateObject private var viewModel: CategoryCorrectionViewModel
    @Environment(\.dismiss) private var dismiss

    let onCorrectionSaved: (String?) -> Void

    /// Creates a CategoryCorrectionSheet for a given place.
    init(placeId: String, currentCategory: String?, hasCorrectionOverride: Bool, onCorrectionSaved: @escaping (String?) -> Void) {
        self._viewModel = StateObject(wrappedValue: CategoryCorrectionViewModel(
            placeId: placeId,
            currentCategory: currentCategory,
            hasCorrectionOverride: hasCorrectionOverride
        ))
        self.onCorrectionSaved = onCorrectionSaved
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                categoryList
            }
            .navigationTitle("Correct Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .onChange(of: viewModel.didComplete) { _, completed in
                if completed {
                    onCorrectionSaved(viewModel.selectedCategory)
                    dismiss()
                }
            }
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Search categories...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
            if !viewModel.searchText.isEmpty {
                Button { viewModel.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var categoryList: some View {
        List {
            if viewModel.hasCorrectionOverride {
                resetSection
            }
            ForEach(viewModel.filteredGroups, id: \.section) { group in
                Section(group.section) {
                    ForEach(group.types, id: \.self) { type in
                        CategoryCorrectionRow(
                            type: type,
                            isSelected: viewModel.selectedCategory == type,
                            onTap: { viewModel.selectCategory(type) }
                        )
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var resetSection: some View {
        Section {
            Button {
                Task { await viewModel.clearCorrection() }
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset to Auto-Detected")
                }
                .foregroundColor(.blue)
            }
            .disabled(viewModel.isSaving)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
                Task { await viewModel.save() }
            }
            .fontWeight(.semibold)
            .disabled(!viewModel.canSave || viewModel.isSaving)
        }
    }
}
