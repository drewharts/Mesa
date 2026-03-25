//
//  ProfileQuickActionsRow.swift
//  loc
//
//  Created by Claude on 3/25/26.
//

import SwiftUI

/// Compact quick-action row displayed below the profile header divider.
struct ProfileQuickActionsRow: View {
    let onImportTap: () -> Void

    private let mesaCharcoal = Color(red: 45/255, green: 45/255, blue: 45/255)

    var body: some View {
        HStack {
            Button(action: onImportTap) {
                HStack(spacing: 5) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 11))
                    Text("Review Places from Photos")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundColor(mesaCharcoal.opacity(0.7))
                .overlay(
                    Capsule()
                        .stroke(mesaCharcoal.opacity(0.3), lineWidth: 1)
                )
            }

            Spacer()
        }
        .padding(.horizontal, 20)
    }
}
