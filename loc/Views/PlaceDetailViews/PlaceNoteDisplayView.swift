//
//  PlaceNoteDisplayView.swift
//  loc
//
//  Compact display view for showing user's private note in the About tab.
//  Only visible to the note owner.
//

import SwiftUI

struct PlaceNoteDisplayView: View {
    @ObservedObject var viewModel: NotesTabViewModel
    let onEditTapped: () -> Void
    
    var body: some View {
        // Only show if user has a note
        if viewModel.hasExistingNote {
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    Image(systemName: "note.text")
                        .foregroundColor(.blue)
                        .font(.system(size: 14, weight: .medium))
                    
                    Text("My Note")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button(action: onEditTapped) {
                        Text("Edit")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                // Note content
                if let note = viewModel.placeNote?.note, !note.isEmpty {
                    Text(note)
                        .font(.footnote)
                        .foregroundColor(.primary)
                        .lineLimit(3)
                }
                
                // Link if present
                if let link = viewModel.placeNote?.link, !link.isEmpty {
                    Button(action: viewModel.openLink) {
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                                .font(.system(size: 10))
                            Text(link)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
            .padding(12)
            .background(Color.blue.opacity(0.05))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
            )
            .padding(.bottom, 16)
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

    // Simulate a note existing
    notesVM.noteText = "Great food but parking is tricky. Ask for the corner booth!"
    notesVM.linkText = "https://example.com/reservation"

    return PlaceNoteDisplayView(viewModel: notesVM, onEditTapped: {})
        .padding()
}

