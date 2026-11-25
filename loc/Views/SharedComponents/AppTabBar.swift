//
//  AppTabBar.swift
//  loc
//
//  DUMB Component: the bottom tab bar (Map, Explore, Trips, Profile). Drawn by the app instead of
//  UITabBar so the map can stay underneath and tab content can slide over it as a sheet.
//

import SwiftUI

struct AppTabBar: View {
    let selected: AppTab
    /// The signed-in user's avatar variants; nil falls back to the person symbol.
    let profileIcon: UIImage?
    let selectedProfileIcon: UIImage?
    let onSelect: (AppTab) -> Void

    private struct Item: Identifiable {
        let tab: AppTab
        let title: String
        let symbol: String
        var id: AppTab { tab }
    }

    private let items: [Item] = [
        Item(tab: .map, title: "Map", symbol: "map"),
        Item(tab: .explore, title: "Explore", symbol: "safari"),
        Item(tab: .trips, title: "Trips", symbol: "airplane"),
        Item(tab: .profile, title: "Profile", symbol: "person.crop.circle")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                Button { onSelect(item.tab) } label: { tabLabel(item) }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.title)
                    .accessibilityAddTraits(item.tab == selected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 2)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, ignoresSafeAreaEdges: .bottom)
        .overlay(alignment: .top) { Color(.separator).opacity(0.6).frame(height: 0.5) }
    }

    // MARK: - Subviews

    private func tabLabel(_ item: Item) -> some View {
        let isSelected = item.tab == selected
        return VStack(spacing: 3) {
            icon(for: item, isSelected: isSelected)
                .frame(height: 26)
            Text(item.title)
                .font(.caption2)
        }
        .foregroundStyle(isSelected ? Color.mesaAccent : Color.secondary)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(
            Capsule()
                .fill(Color.mesaAccent.opacity(isSelected ? 0.14 : 0))
                .padding(.horizontal, 8)
        )
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func icon(for item: Item, isSelected: Bool) -> some View {
        let avatar = isSelected ? selectedProfileIcon : profileIcon
        if item.tab == .profile, let avatar {
            Image(uiImage: avatar).renderingMode(.original)
        } else {
            // symbolVariant falls back to the plain glyph when no .fill exists (e.g. airplane).
            Image(systemName: item.symbol)
                .symbolVariant(isSelected ? .fill : .none)
                .font(.system(size: 22))
        }
    }
}
