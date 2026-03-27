//
//  FeedTabButton.swift
//  loc
//
//  DUMB Component: A single tab button for the Feed/Explore tab header.
//

import SwiftUI

struct FeedTabButton: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .bold : .regular)
                .foregroundColor(isSelected ? .primary : .secondary)
        }
        .buttonStyle(.plain)
    }
}
