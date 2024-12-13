//
//  NewListView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/25/24.
//


import SwiftUI

struct NewListView: View {
    @Binding var isPresented: Bool
    var onSave: (String) -> Void
    
    @State private var listName: String = ""
    @State private var showError: Bool = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("List Name")) {
                    TextField("Enter list name", text: $listName)
                }
                
                if showError {
                    Text("List name cannot be empty.")
                        .foregroundColor(.red)
                }
            }
            .navigationBarTitle("New List", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                },
                trailing: Button("Save") {
                    saveList()
                }
                .disabled(listName.trimmingCharacters(in: .whitespaces).isEmpty)
            )
        }
    }
    
    private func saveList() {
        let trimmedName = listName.trimmingCharacters(in: .whitespaces)
        if trimmedName.isEmpty {
            showError = true
        } else {
            onSave(trimmedName)
            isPresented = false
        }
    }
}
