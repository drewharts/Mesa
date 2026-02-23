//
//  ProfileTabHeader.swift
//  loc
//
//  Reusable tab header for profile sections (Favorites, Videos, Reviews).
//  Matches MyProfile styling exactly.
//
//  Single Responsibility: Display and manage tab selection with consistent styling.
//

import SwiftUI

/// Represents a single tab in the profile tab header.
struct ProfileTab: Identifiable, Equatable {
    let id: String
    let title: String
    let icon: String?
    let showHelpButton: Bool

    init(id: String, title: String, icon: String? = nil, showHelpButton: Bool = false) {
        self.id = id
        self.title = title
        self.icon = icon
        self.showHelpButton = showHelpButton
    }

    // MARK: - Predefined Tabs

    static let favorites = ProfileTab(id: "favorites", title: "Favorites")
    static let externalPlaces = ProfileTab(id: "externalPlaces", title: "Videos", showHelpButton: true)
    static let reviews = ProfileTab(id: "reviews", title: "Reviews")
    static let myPlaces = ProfileTab(id: "myPlaces", title: "My Places")
}

/// Reusable tab header for profile sections.
struct ProfileTabHeader: View {
    let tabs: [ProfileTab]
    @Binding var selectedTabId: String
    var onHelpTap: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            ForEach(tabs) { tab in
                tabButton(for: tab)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Tab Button

    @ViewBuilder
    private func tabButton(for tab: ProfileTab) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTabId = tab.id
            }
        }) {
            HStack(spacing: 4) {
                Text(tab.title)
                    .font(.headline)
                    .fontWeight(selectedTabId == tab.id ? .semibold : .regular)
                    .foregroundColor(selectedTabId == tab.id ? .primary : .gray)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                // Help button shown only when tab is selected and has showHelpButton enabled
                if tab.showHelpButton && selectedTabId == tab.id {
                    helpButton
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var helpButton: some View {
        if let onHelpTap = onHelpTap {
            Button(action: onHelpTap) {
                Image(systemName: "questionmark.circle")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
        }
    }
}
