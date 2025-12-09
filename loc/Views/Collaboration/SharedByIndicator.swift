//
//  SharedByIndicator.swift
//  loc
//
//  DUMB Component: Shows who shared a list with the current user
//  Single Responsibility: Display owner info + collaborator avatars for shared lists
//
//  Uses CachedProfileImage for efficient image loading with memory + disk caching
//
//  Usage: Used in list cards when viewing a list shared WITH you (collaborator view)
//

import SwiftUI

struct SharedByIndicator: View {
    let ownerName: String?
    var ownerPhotoUrl: String? = nil
    var collaboratorPhotos: [String]? = nil
    
    // MARK: - Constants
    
    private let ownerAvatarSize: CGFloat = 20
    private let collaboratorAvatarSize: CGFloat = 16
    
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
        CachedProfileImage(
            url: ownerPhotoUrl,
            size: ownerAvatarSize,
            fallbackInitial: String(firstName.prefix(1).uppercased())
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
                    CachedProfileImage(
                        url: photoUrl,
                        size: collaboratorAvatarSize,
                        fallbackInitial: "?"
                    )
                    .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1))
                    .zIndex(Double(3 - index))
                }
                
                if photos.count > 3 {
                    overflowBadge(count: photos.count - 3)
                }
            }
        }
    }
    
    private func overflowBadge(count: Int) -> some View {
        Circle()
            .fill(Color.gray.opacity(0.7))
            .frame(width: collaboratorAvatarSize, height: collaboratorAvatarSize)
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
        Text("Basic - No photo").font(.caption2).foregroundColor(.gray)
        SharedByIndicator(ownerName: "Sarah Jones")
        
        Text("With collaborators").font(.caption2).foregroundColor(.gray)
        SharedByIndicator(
            ownerName: "Sarah Jones",
            ownerPhotoUrl: nil,
            collaboratorPhotos: ["url1", "url2"]
        )
        
        Text("Many collaborators (overflow)").font(.caption2).foregroundColor(.gray)
        SharedByIndicator(
            ownerName: "Sarah Jones",
            ownerPhotoUrl: nil,
            collaboratorPhotos: ["url1", "url2", "url3", "url4", "url5"]
        )
    }
    .padding()
}

