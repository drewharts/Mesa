//
//  PlaceNoteView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/29/25.
//

import SwiftUI

struct PlaceNoteView: View {
    let place: DetailPlace
    @EnvironmentObject var profile: ProfileViewModel
    @State private var noteText: String = ""
    @State private var linkText: String = ""
    @State private var isEditing: Bool = false
    @State private var showingDeleteAlert: Bool = false
    
    private var currentPlaceNote: PlaceNote? {
        profile.getPlaceNote(for: place.id.uuidString)
    }
    
    private var hasExistingNote: Bool {
        return currentPlaceNote?.hasContent ?? false
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(.blue)
                    .font(.system(size: 16, weight: .medium))
                
                Text("My Notes")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if hasExistingNote {
                    Button(action: {
                        showingDeleteAlert = true
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .font(.system(size: 16, weight: .medium))
                    }
                }
                
                Button(action: {
                    if isEditing {
                        saveNote()
                    } else {
                        loadExistingNote()
                        isEditing = true
                    }
                }) {
                    Text(isEditing ? "Save" : hasExistingNote ? "Edit" : "Add Note")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            if isEditing {
                // Editing mode
                VStack(spacing: 12) {
                    // Note text field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Note")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        TextEditor(text: $noteText)
                            .frame(minHeight: 80)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                    }
                    
                    // Link text field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Link (optional)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        TextField("https://example.com", text: $linkText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            } else if hasExistingNote {
                // Display mode
                VStack(alignment: .leading, spacing: 8) {
                    if let note = currentPlaceNote?.note, !note.isEmpty {
                        Text(note)
                            .font(.body)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 20)
                    }
                    
                    if let link = currentPlaceNote?.link, !link.isEmpty {
                        Button(action: {
                            if let url = URL(string: link) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "link")
                                    .font(.system(size: 12))
                                Text(link)
                                    .font(.caption)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .foregroundColor(.blue)
                            .padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.bottom, 16)
            } else {
                // Empty state
                VStack(spacing: 8) {
                    Text("Add a personal note or link for this place")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("Your notes are private and only visible to you")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
        .onAppear {
            loadExistingNote()
        }
        .alert("Delete Note", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteNote()
            }
        } message: {
            Text("Are you sure you want to delete your note for this place?")
        }
    }
    
    private func loadExistingNote() {
        if let placeNote = currentPlaceNote {
            noteText = placeNote.note ?? ""
            linkText = placeNote.link ?? ""
        } else {
            noteText = ""
            linkText = ""
        }
    }
    
    private func saveNote() {
        let trimmedNote = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLink = linkText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        profile.savePlaceNote(for: place.id.uuidString, note: trimmedNote.isEmpty ? nil : trimmedNote, link: trimmedLink.isEmpty ? nil : trimmedLink)
        
        isEditing = false
    }
    
    private func deleteNote() {
        profile.deletePlaceNote(for: place.id.uuidString)
        noteText = ""
        linkText = ""
        isEditing = false
    }
}
