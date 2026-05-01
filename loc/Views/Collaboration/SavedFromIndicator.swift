//
//  SavedFromIndicator.swift
//  loc
//
//  DUMB Component: Shows who created a saved list
//  Single Responsibility: Display owner info for saved lists
//

import SwiftUI

/// Displays the creator of a saved list with their avatar.
struct SavedFromIndicator: View {
    let ownerName: String
    var ownerPhotoUrl: String? = nil

    private let avatarSize: CGFloat = 20

    private var firstName: String {
        ownerName.components(separatedBy: " ").first ?? "Someone"
    }

    var body: some View {
        HStack(spacing: 6) {
            CachedProfileImage(
                url: ownerPhotoUrl,
                size: avatarSize,
                fallbackInitial: String(firstName.prefix(1).uppercased())
            )

            Text("Saved from \(firstName)")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}
