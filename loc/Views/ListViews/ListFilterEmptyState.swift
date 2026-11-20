//
//  ListFilterEmptyState.swift
//  loc
//
//  Message under the chip row when the selected chip shows no tiles: "none match" or a retry prompt.
//

import SwiftUI

struct ListFilterEmptyState: View {
    /// True when matching places exist but could not be loaded.
    let loadFailed: Bool
    /// Overrides the default "none match" text, e.g. for a search with no results.
    var message: String? = nil
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(loadFailed ? "Couldn't load matching places" : (message ?? "No places match this filter"))
                .font(.subheadline)
                .foregroundColor(.secondary)
            if loadFailed {
                Button("Try again", action: onRetry)
                    .font(.subheadline.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
