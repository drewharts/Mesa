//
//  ListTypeFilterRow.swift
//  loc
//
//  DUMB Component: horizontally scrolling row of tag chips at the top of a list.
//  The selected chip scrolls into view.
//

import SwiftUI

struct ListTypeFilterRow: View {
    let chips: [ListTypeChip]
    let isSelected: (ListTypeChip) -> Bool
    let onSelect: (ListTypeChip) -> Void

    private var selectedId: String? { chips.first(where: isSelected)?.id }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(chips) { chip in
                        FilterChip(label: chip.title, isSelected: isSelected(chip), onTap: { onSelect(chip) })
                            .id(chip.id)
                    }
                }
                .padding(.horizontal, 16)
            }
            .onChange(of: selectedId) { _, id in
                guard let id else { return }
                withAnimation(.easeInOut(duration: 0.25)) { proxy.scrollTo(id, anchor: .center) }
            }
        }
    }
}
