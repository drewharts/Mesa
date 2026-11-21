//
//  ListTypeFilterRow.swift
//  loc
//
//  DUMB Component: horizontally scrolling row of tag chips at the top of a list.
//  Starts with a search button that expands into a field narrowing the chips; the selected chip scrolls into view.
//

import SwiftUI

struct ListTypeFilterRow: View {
    let chips: [ListTypeChip]
    let isSelected: (ListTypeChip) -> Bool
    let onSelect: (ListTypeChip) -> Void
    let isSearching: Bool
    let searchQuery: Binding<String>
    let onBeginSearch: () -> Void
    let onClearOrCloseSearch: () -> Void
    let onCollapseSearch: () -> Void
    /// Shows the "Find a table" chip after the search button; off when the backend does not offer it.
    var showsFindTable: Bool = false
    var isFindTableActive: Bool = false
    var onFindTable: () -> Void = {}

    @ScaledMetric(relativeTo: .subheadline) private var rowHeight: CGFloat = 36

    private var selectedId: String? { chips.first(where: isSelected)?.id }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ListChipSearchField(query: searchQuery, isActive: isSearching, onActivate: onBeginSearch,
                                        onClearOrClose: onClearOrCloseSearch, onCollapse: onCollapseSearch)
                    if showsFindTable {
                        FindTableChip(isActive: isFindTableActive, onTap: onFindTable)
                    }
                    ForEach(chips) { chip in
                        FilterChip(label: chip.title, isSelected: isSelected(chip), onTap: { onSelect(chip) })
                            .id(chip.id)
                            .transition(.opacity)
                    }
                }
                .frame(minHeight: rowHeight)
                .padding(.horizontal, 16)
                .animation(.easeInOut(duration: 0.22), value: isSearching)
                .animation(.easeInOut(duration: 0.2), value: chips.map(\.id))
            }
            .onChange(of: selectedId) { _, id in
                guard let id else { return }
                withAnimation(.easeInOut(duration: 0.25)) { proxy.scrollTo(id, anchor: .center) }
            }
        }
    }
}
