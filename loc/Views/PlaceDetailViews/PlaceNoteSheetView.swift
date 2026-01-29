//
//  PlaceNoteSheetView.swift
//  loc
//
//  Created for editing private place notes in a sheet presentation.
//

import SwiftUI

struct PlaceNoteSheetView: View {
    @ObservedObject var viewModel: NotesTabViewModel
    @Environment(\.dismiss) private var dismiss
    
    // Local state for showing link field
    @State private var showLinkField = false
    
    // Match sheet corner radius
    private let cornerRadius: CGFloat = 16
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                // Info text
                Text("Private notes are only visible to you")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                // Note text field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Note")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $viewModel.noteText)
                        .frame(minHeight: 120)
                        .padding(12)
                        .scrollContentBackground(.hidden)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                }
                .padding(.horizontal)
                
                // Link section - show field or add button
                if showLinkField || !viewModel.linkText.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Link")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            // Remove link button
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.linkText = ""
                                    showLinkField = false
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 18))
                            }
                        }
                        
                        TextField("https://example.com", text: $viewModel.linkText)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                            .overlay(
                                RoundedRectangle(cornerRadius: cornerRadius)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    .padding(.horizontal)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    // Add link button
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showLinkField = true
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16))
                            Text("Add Link")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.gray)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // Delete button (only show if note exists)
                if viewModel.hasExistingNote {
                    Button(action: {
                        viewModel.showDeleteAlert()
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Note")
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("My Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        viewModel.cancelEditing()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        viewModel.saveNote()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("Delete Note", isPresented: $viewModel.showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    viewModel.deleteNote()
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to delete your note for this place?")
            }
        }
        .onAppear {
            viewModel.prepareForEditing()
            // Show link field if there's already a link
            showLinkField = !viewModel.linkText.isEmpty
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

    return PlaceNoteSheetView(viewModel: notesVM)
}

