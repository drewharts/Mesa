//
//  ListCreatorChip.swift
//  loc
//
//  DUMB Component: small pill with a circular avatar and a creator's name; tappable when `onTap` is set.
//

import SwiftUI

/// Avatar + name pill identifying who made a list.
struct ListCreatorChip: View {
    let name: String
    let photoURL: String?
    let onTap: (() -> Void)?

    var body: some View {
        if let onTap {
            Button(action: onTap) { chip }
                .buttonStyle(.plain)
                .accessibilityHint("Opens profile")
        } else {
            chip
        }
    }

    private var chip: some View {
        HStack(spacing: 6) {
            avatar
            Text(name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.leading, 3)
        .padding(.trailing, 10)
        .padding(.vertical, 3)
        .background(Color(.systemGray6))
        .clipShape(Capsule())
    }

    private var avatar: some View {
        AsyncImage(url: photoURL.flatMap { URL(string: $0) }) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Image(systemName: "person.fill")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGray5))
        }
        .frame(width: 22, height: 22)
        .clipShape(Circle())
    }
}
