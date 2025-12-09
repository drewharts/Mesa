//
//  SharedByIndicator.swift
//  loc
//
//  DUMB Component: Shows who shared a list with the current user
//  Single Responsibility: Display owner info + collaborator avatars for shared lists
//
//  Usage: Used in list cards when viewing a list shared WITH you (collaborator view)
//

import SwiftUI

struct SharedByIndicator: View {
    let ownerName: String?
    var ownerPhotoUrl: String? = nil
    var collaboratorPhotos: [String]? = nil
    
    // MARK: - Computed Properties
    
    private var firstName: String {
        ownerName?.components(separatedBy: " ").first ?? "Someone"
    }
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 8) {
            ownerAvatar
            ownerLabel
            collaboratorAvatars
        }
    }
    
    // MARK: - Subviews
    
    private var ownerAvatar: some View {
        AsyncImage(url: URL(string: ownerPhotoUrl ?? "")) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                placeholderAvatar
            }
        }
        .frame(width: 20, height: 20)
        .clipShape(Circle())
    }
    
    private var placeholderAvatar: some View {
        Circle()
            .fill(Color.blue.opacity(0.2))
            .overlay(
                Text(firstName.prefix(1).uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.blue)
            )
    }
    
    private var ownerLabel: some View {
        Text("Shared by \(firstName)")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    
    @ViewBuilder
    private var collaboratorAvatars: some View {
        if let photos = collaboratorPhotos, !photos.isEmpty {
            HStack(spacing: -6) {
                ForEach(Array(photos.prefix(3).enumerated()), id: \.offset) { index, photoUrl in
                    collaboratorAvatar(photoUrl: photoUrl, zIndex: 3 - index)
                }
                
                if photos.count > 3 {
                    overflowBadge(count: photos.count - 3)
                }
            }
        }
    }
    
    private func collaboratorAvatar(photoUrl: String, zIndex: Int) -> some View {
        AsyncImage(url: URL(string: photoUrl)) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                Circle().fill(Color.gray.opacity(0.3))
            }
        }
        .frame(width: 16, height: 16)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1))
        .zIndex(Double(zIndex))
    }
    
    private func overflowBadge(count: Int) -> some View {
        Circle()
            .fill(Color.gray.opacity(0.7))
            .frame(width: 16, height: 16)
            .overlay(
                Text("+\(count)")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(.white)
            )
            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1))
    }
}

// MARK: - Preview

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        SharedByIndicator(ownerName: "Sarah Jones")
        
        SharedByIndicator(
            ownerName: "Sarah Jones",
            ownerPhotoUrl: nil,
            collaboratorPhotos: ["url1", "url2"]
        )
        
        SharedByIndicator(
            ownerName: "Sarah Jones",
            ownerPhotoUrl: nil,
            collaboratorPhotos: ["url1", "url2", "url3", "url4", "url5"]
        )
    }
    .padding()
}

