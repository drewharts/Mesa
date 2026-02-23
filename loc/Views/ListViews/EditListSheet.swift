//
//  EditListSheet.swift
//  loc
//
//  Sheet for editing a list's name and description.
//

import SwiftUI

struct EditListSheet: View {
    @StateObject private var viewModel: EditListViewModel
    @Environment(\.dismiss) private var dismiss

    let onSave: ((String, String?) -> Void)?

    init(listId: String, currentName: String, currentDescription: String?, onSave: ((String, String?) -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: EditListViewModel(
            listId: listId,
            currentName: currentName,
            currentDescription: currentDescription
        ))
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("List name", text: $viewModel.name)
                        .disabled(viewModel.isSaving)
                }

                Section("Description") {
                    TextField("Add a description", text: $viewModel.descriptionText)
                        .disabled(viewModel.isSaving)
                }
            }
            .navigationTitle("Edit List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if await viewModel.save() {
                                let trimmedDesc = viewModel.descriptionText.trimmingCharacters(in: .whitespaces)
                                onSave?(
                                    viewModel.name.trimmingCharacters(in: .whitespaces),
                                    trimmedDesc.isEmpty ? nil : trimmedDesc
                                )
                                dismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.hasChanges || !viewModel.isNameValid || viewModel.isSaving)
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
    EditListSheet(
        listId: "test-id",
        currentName: "My List",
        currentDescription: nil
    )
}
