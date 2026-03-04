//
//  ProfileStatBadge.swift
//  loc
//
//  Reusable badge shown on profile pictures (e.g. places count, countries count).
//  Single source of truth for the frosted-capsule styling used across own and external profiles.
//

import SwiftUI

struct ProfileStatBadge: View {
    let displayText: String
    let systemImage: String?
    let action: () -> Void

    // MARK: - Convenience initializer for numeric counts
    init(count: Int, systemImage: String? = nil, action: @escaping () -> Void) {
        self.displayText = count >= 1000 ? "\(count / 1000)k+" : "\(count)"
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 9, weight: .medium))
                }
                Text(displayText)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
            }
            .foregroundColor(.secondary)
            .frame(minWidth: 24)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}
