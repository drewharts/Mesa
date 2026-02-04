//
//  ListSettingsSheet.swift
//  loc
//
//  Sheet UI for managing list settings including privacy toggle.
//

import SwiftUI

struct ListSettingsSheet: View {
    @StateObject private var viewModel: ListSettingsViewModel
    @Environment(\.dismiss) private var dismiss

    let onSave: ((Bool) -> Void)?

    init(listId: String, initialIsPublic: Bool, onSave: ((Bool) -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: ListSettingsViewModel(
            listId: listId,
            initialIsPublic: initialIsPublic
        ))
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Private List", isOn: Binding(
                        get: { !viewModel.isPublic },
                        set: { viewModel.isPublic = !$0 }
                    ))
                    .disabled(viewModel.isSaving)
                } footer: {
                    Text("Private lists only show places on the map for you and collaborators.")
                }
            }
            .navigationTitle("List Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if await viewModel.savePrivacySetting() {
                                onSave?(viewModel.isPublic)
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}

#Preview {
    ListSettingsSheet(
        listId: "test-id",
        initialIsPublic: true
    )
}
