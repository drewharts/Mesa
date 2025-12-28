//
//  NewListSheetView.swift
//  loc
//
//  DUMB Component: Compact sheet for creating a new list
//  Single Responsibility: Render create list form UI and handle save/cancel
//
//  Designed for partial-height presentation (~quarter screen)
//
//  Created by Cursor on 12/28/24.
//

import SwiftUI

struct NewListSheetView: View {
    @Environment(\.dismiss) private var dismiss
    
    let onSave: (String) async -> Void
    
    @State private var listName: String = ""
    @State private var isSaving: Bool = false
    @FocusState private var isTextFieldFocused: Bool
    
    private let cornerRadius: CGFloat = 12
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                // Text field section
                VStack(alignment: .leading, spacing: 8) {
                    Text("List Name")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    TextField("Enter list name", text: $listName)
                        .padding(14)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                        .disabled(isSaving)
                        .focused($isTextFieldFocused)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Loading indicator
                if isSaving {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Creating list...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationTitle("New List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await saveList()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(listName.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
        .onAppear {
            // Auto-focus the text field when sheet appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isTextFieldFocused = true
            }
        }
    }
    
    // MARK: - Actions
    
    private func saveList() async {
        let trimmedName = listName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        
        isSaving = true
        await onSave(trimmedName)
        isSaving = false
        dismiss()
    }
}

#Preview {
    NewListSheetView(onSave: { name in
        print("Creating list: \(name)")
    })
}
