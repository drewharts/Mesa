//
//  ListRowThumbnail.swift
//  loc
//
//  DUMB Component: Displays thumbnail for list selection rows
//  Single Responsibility: Show collaborator avatars for shared lists, nothing for owned lists
//
//  Usage: Used in ListSelectionSheet rows to visually differentiate shared lists
//

import SwiftUI

struct ListRowThumbnail: View {
    let isShared: Bool
    let ownerPhotoUrl: String?
    let ownerName: String?
    let collaboratorPhotos: [String]?
    
    private let size: CGFloat = 60
    private let avatarSize: CGFloat = 28
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            if isShared {
                sharedListThumbnail
            }
            // Owned lists show nothing (clean design)
        }
        .frame(width: size, height: size)
    }
    
    // MARK: - Shared List Thumbnail
    
    private var sharedListThumbnail: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.1))
            
            // Avatar stack
            avatarStack
        }
    }
    
    private var avatarStack: some View {
        HStack(spacing: -10) {
            // Owner avatar (always first)
            avatarView(
                photoUrl: ownerPhotoUrl,
                fallbackInitial: ownerName?.prefix(1).uppercased() ?? "?",
                isOwner: true
            )
            
            // Collaborator avatars (up to 2 more)
            if let photos = collaboratorPhotos {
                ForEach(Array(photos.prefix(2).enumerated()), id: \.offset) { index, photoUrl in
                    avatarView(
                        photoUrl: photoUrl,
                        fallbackInitial: "?",
                        isOwner: false
                    )
                    .zIndex(Double(-index))
                }
                
                // Overflow indicator
                if photos.count > 2 {
                    overflowBadge(count: photos.count - 2)
                        .zIndex(-3)
                }
            }
        }
    }
    
    // MARK: - Avatar Components
    
    private func avatarView(photoUrl: String?, fallbackInitial: String, isOwner: Bool) -> some View {
        AsyncImage(url: URL(string: photoUrl ?? "")) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                Circle()
                    .fill(isOwner ? Color.blue.opacity(0.3) : Color.gray.opacity(0.3))
                    .overlay(
                        Text(fallbackInitial)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(isOwner ? .blue : .gray)
                    )
            }
        }
        .frame(width: avatarSize, height: avatarSize)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
    }
    
    private func overflowBadge(count: Int) -> some View {
        Circle()
            .fill(Color.blue.opacity(0.8))
            .frame(width: avatarSize, height: avatarSize)
            .overlay(
                Text("+\(count)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
            )
            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 20) {
            // Owned list (empty)
            VStack {
                ListRowThumbnail(
                    isShared: false,
                    ownerPhotoUrl: nil,
                    ownerName: nil,
                    collaboratorPhotos: nil
                )
                Text("Owned").font(.caption)
            }
            
            // Shared with 1 collaborator
            VStack {
                ListRowThumbnail(
                    isShared: true,
                    ownerPhotoUrl: nil,
                    ownerName: "Sarah",
                    collaboratorPhotos: nil
                )
                Text("Shared (1)").font(.caption)
            }
            
            // Shared with multiple collaborators
            VStack {
                ListRowThumbnail(
                    isShared: true,
                    ownerPhotoUrl: nil,
                    ownerName: "Sarah",
                    collaboratorPhotos: ["url1", "url2", "url3", "url4"]
                )
                Text("Shared (4)").font(.caption)
            }
        }
    }
    .padding()
}

