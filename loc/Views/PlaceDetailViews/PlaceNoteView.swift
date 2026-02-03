//
//  PlaceNoteView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/29/25.
//  Refactored to use NotesTabViewModel for proper MVVM
//

import SwiftUI

struct PlaceNoteView: View {
    @ObservedObject var viewModel: NotesTabViewModel
    
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
                
                if viewModel.hasExistingNote {
                    Button(action: {
                        viewModel.showDeleteAlert()
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .font(.system(size: 16, weight: .medium))
                    }
                }
                
                Button(action: {
                    viewModel.toggleEditing()
                }) {
                    Text(viewModel.saveButtonTitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            if viewModel.isEditing {
                // Editing mode
                VStack(spacing: 12) {
                    // Note text field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Note")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        TextEditor(text: $viewModel.noteText)
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
                        
                        TextField("https://example.com", text: $viewModel.linkText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            } else if viewModel.hasExistingNote {
                // Display mode
                VStack(alignment: .leading, spacing: 8) {
                    if let note = viewModel.placeNote?.note, !note.isEmpty {
                        Text(note)
                            .font(.body)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 20)
                    }
                    
                    if let link = viewModel.placeNote?.link, !link.isEmpty {
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
        .alert("Delete Note", isPresented: $viewModel.showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.deleteNote()
            }
        } message: {
            Text("Are you sure you want to delete your note for this place?")
        }
    }
}

// MARK: - Preview
#Preview {
    let services = ServiceContainer.shared
    let locationManager = LocationManager()
    
    let detailPlaceVM = DetailPlaceViewModel(
        placeService: services.placeService,
        userService: services.userService
    )
    
    let selectedPlaceVM = SelectedPlaceViewModel(
        locationManager: locationManager,
        postService: services.postService,
        placeService: services.placeService,
        userService: services.userService,
        imageService: services.imageService,
        detailPlaceViewModel: detailPlaceVM
    )
    
    let userSession = UserSession(
        userService: services.userService,
        locationManager: locationManager,
        detailPlaceVM: detailPlaceVM
    )
    
    let profileVM = ProfileViewModel(
        userSession: userSession,
        userService: services.userService,
        detailPlaceViewModel: detailPlaceVM,
        imageService: services.imageService,
        placeService: services.placeService,
        postService: services.postService,
        locationManager: locationManager,
        deepLinkManager: services.deepLinkManager,
        deepLinkViewModel: nil
    )
    
    let notesVM = NotesTabViewModel(userSession: userSession)

    var mockPlace = DetailPlace()
    mockPlace.name = "Sample Restaurant"
    notesVM.setPlace(mockPlace)

    return PlaceNoteView(viewModel: notesVM)
        .padding()
}
