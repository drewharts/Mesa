//
//  FindTableMessageView.swift
//  loc
//
//  DUMB Component: empty ("no tables") and error ("Couldn't check right now") state of a table search.
//

import SwiftUI

struct FindTableMessageView: View {
    let title: String
    let detail: String?
    let primaryTitle: String
    let onPrimary: () -> Void
    let onExit: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.headline)
            if let detail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 20) {
                Button(primaryTitle, action: onPrimary)
                Button("Show all places", action: onExit)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 24)
    }
}
