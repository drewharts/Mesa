//
//  SuggestedProfileRowView.swift
//  loc
//
//  DUMB Component: Displays a single suggested profile row.
//  Single Responsibility: Render profile photo, name, and chevron indicator.
//

import SwiftUI

struct SuggestedProfileRowView: View {
    let profile: ProfileData
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                CachedProfileImage(
                    url: profile.profilePhotoURL?.absoluteString,
                    size: 48,
                    fallbackInitial: String(profile.firstName.prefix(1))
                )

                Text(profile.fullName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    VStack {
        SuggestedProfileRowView(
            profile: ProfileData(
                id: "1",
                firstName: "Drew",
                lastName: "Hartsfield",
                email: "drew@example.com",
                profilePhotoURL: nil,
                phoneNumber: "",
                fullNameLower: "drew hartsfield",
                fullName: "Drew Hartsfield",
                fcmToken: nil,
                firebaseUid: nil,
                supabaseUid: nil
            ),
            onTap: {}
        )
        .padding(.horizontal)
    }
}
