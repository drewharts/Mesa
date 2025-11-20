//
//  NewListView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/25/24.
//


import SwiftUI

struct NewListView: View {
    @Binding var isPresented: Bool
    var onSave: (String) async -> Void  // Changed to async closure
    
    @State private var listName: String = ""
    @State private var showError: Bool = false
    @State private var isSaving: Bool = false  // New loading state
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("List Name")) {
                    TextField("Enter list name", text: $listName)
                        .disabled(isSaving)  // Disable during save
                }
                
                if showError {
                    Text("List name cannot be empty.")
                        .foregroundColor(.red)
                }
                
                if isSaving {
                    HStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("Creating list...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
            .navigationBarTitle("New List", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                }
                .disabled(isSaving),  // Disable during save
                trailing: Button("Save") {
                    Task {
                        await saveList()
                    }
                }
                .disabled(listName.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
            )
        }
    }
    
    private func saveList() async {
        let trimmedName = listName.trimmingCharacters(in: .whitespaces)
        if trimmedName.isEmpty {
            showError = true
        } else {
            isSaving = true
            await onSave(trimmedName)  // Wait for creation to complete
            isSaving = false
            isPresented = false  // Dismiss AFTER creation
        }
    }
}
