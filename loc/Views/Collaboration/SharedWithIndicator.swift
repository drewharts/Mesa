//
//  SharedWithIndicator.swift
//  loc
//
//  DUMB Component: Shows who the owner has shared a list with
//  Single Responsibility: Display place count + collaborator avatars for owned lists
//
//  Uses CachedProfileImage for efficient image loading with memory + disk caching
//
//  Usage: Used in list cards when viewing YOUR OWN lists (owner view)
//

import SwiftUI

struct SharedWithIndicator: View {
    let collaboratorPhotos: [String]?
    let collaboratorCount: Int
    let placeCount: Int
    
    // MARK: - Constants
    
    private let avatarSize: CGFloat = 18
    
    // MARK: - Computed Properties
    
    private var hasCollaborators: Bool {
        collaboratorCount > 0
    }
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 6) {
            placeCountLabel
            
            if hasCollaborators {
                separator
                sharedWithLabel
                collaboratorAvatars
            }
        }
    }
    
    // MARK: - Subviews
    
    private var placeCountLabel: some View {
        Text("\(placeCount) place\(placeCount == 1 ? "" : "s")")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    
    private var separator: some View {
        Text("•")
            .font(.caption)
            .foregroundColor(.secondary.opacity(0.5))
    }
    
    private var sharedWithLabel: some View {
        Text("Shared with")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    
    private var collaboratorAvatars: some View {
        HStack(spacing: -6) {
            ForEach(Array((collaboratorPhotos ?? []).prefix(3).enumerated()), id: \.offset) { index, photoUrl in
                CachedProfileImage(
                    url: photoUrl,
                    size: avatarSize,
                    fallbackInitial: "?"
                )
                .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))
                .zIndex(Double(3 - index))
            }
            
            if collaboratorCount > 3 {
                overflowBadge(count: collaboratorCount - 3)
            }
        }
    }
    
    private func overflowBadge(count: Int) -> some View {
        Circle()
            .fill(Color.gray.opacity(0.7))
            .frame(width: avatarSize, height: avatarSize)
            .overlay(
                Text("+\(count)")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white)
            )
            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))
    }
}

// MARK: - Preview

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        Text("No collaborators").font(.caption2).foregroundColor(.gray)
        SharedWithIndicator(
            collaboratorPhotos: nil,
            collaboratorCount: 0,
            placeCount: 8
        )
        
        Text("With collaborators").font(.caption2).foregroundColor(.gray)
        SharedWithIndicator(
            collaboratorPhotos: ["url1", "url2"],
            collaboratorCount: 2,
            placeCount: 12
        )
        
        Text("Many collaborators (overflow)").font(.caption2).foregroundColor(.gray)
        SharedWithIndicator(
            collaboratorPhotos: ["url1", "url2", "url3", "url4", "url5"],
            collaboratorCount: 5,
            placeCount: 5
        )
    }
    .padding()
}

