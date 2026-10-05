//
//  ContactsConsentCard.swift
//  loc
//
//  DUMB Component: In-app disclosure shown before any contacts are read or uploaded.
//  Single Responsibility: Explain what contact data is uploaded and how it is used,
//  and capture the user's explicit allow / decline choice (App Store Guideline 5.1.2).
//

import SwiftUI

struct ContactsConsentCard: View {
    let onAllow: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 32))
                .foregroundColor(.accentColor)

            Text("Find friends from your contacts")
                .font(.headline)

            Text("To find friends already on Mesa, we'll upload the phone numbers in your contacts to Mesa's servers and compare them with the phone numbers of Mesa accounts. They're used only for this match. We don't store them, share them, or contact anyone in your address book.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onAllow) {
                Text("Allow & Find Friends")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button("Not Now", action: onDecline)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(16)
    }
}

#Preview {
    ContactsConsentCard(onAllow: {}, onDecline: {})
}
