//
//  FeedTabButton.swift
//  loc
//
//  DUMB Component: A single tab button for the Feed/Explore tab header.
//  Clean typography with underline indicator for selected state.
//

import SwiftUI

struct FeedTabButton: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.title3)
                    .fontWeight(isSelected ? .bold : .regular)
                    .foregroundColor(isSelected ? .primary : .secondary)

                Rectangle()
                    .fill(isSelected ? Color.primary : Color.clear)
                    .frame(height: 2)
            }
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
    }
}
