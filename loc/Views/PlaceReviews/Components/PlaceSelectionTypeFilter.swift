//  PlaceSelectionTypeFilter.swift
//  loc
//
//  DUMB Component: Horizontal scroll of capsule filter pills for place types.
//  Single Responsibility: Render type filter pills and report selection changes.

import SwiftUI

struct PlaceSelectionTypeFilter: View {
    let types: [String]
    let selectedType: String?
    let onSelectType: (String?) -> Void

    private let mesaCharcoal = Color(red: 45/255, green: 45/255, blue: 45/255)

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                allPill
                ForEach(types, id: \.self) { type in
                    typePill(for: type)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 8)
    }

    private var allPill: some View {
        Button {
            onSelectType(nil)
        } label: {
            Text("All")
                .font(.subheadline)
                .fontWeight(selectedType == nil ? .semibold : .regular)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(selectedType == nil ? mesaCharcoal : Color(.systemGray6))
                .foregroundColor(selectedType == nil ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    /// Renders a single type filter pill with emoji and label.
    private func typePill(for type: String) -> some View {
        let isSelected = selectedType == type
        let emoji = PlaceTypeEmoji.emoji(for: type)
        let displayName = type
            .replacingOccurrences(of: "_", with: " ")
            .capitalized

        return Button {
            onSelectType(type)
        } label: {
            HStack(spacing: 4) {
                Text(emoji)
                    .font(.subheadline)
                Text(displayName)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? mesaCharcoal : Color(.systemGray6))
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
