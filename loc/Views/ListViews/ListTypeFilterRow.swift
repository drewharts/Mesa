//
//  ListTypeFilterRow.swift
//  loc
//
//  DUMB Component: horizontally scrolling row of type chips at the top of a list.
//

import SwiftUI

struct ListTypeFilterRow: View {
    let chips: [ListTypeChip]
    let isSelected: (ListTypeChip) -> Bool
    let onSelect: (ListTypeChip) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chips) { chip in
                    FilterChip(label: chip.title, isSelected: isSelected(chip), onTap: { onSelect(chip) })
                }
            }
            .padding(.horizontal, 16)
        }
    }
}
