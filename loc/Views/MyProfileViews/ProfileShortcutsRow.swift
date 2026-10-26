//
//  ProfileShortcutsRow.swift
//  loc
//
//  Feed and Trips moved here from the map's bottom bar (4.92 nav consolidation).
//  Tapping closes the profile and opens the existing Feed / Trips sheet on the map.
//

import SwiftUI

struct ProfileShortcutsRow: View {
    /// (sheet to open on the map, analytics item name)
    let onSelect: (AppSheetType, String) -> Void

    var body: some View {
        HStack(spacing: 10) {
            shortcut(title: "Feed", item: "feed", sheet: .feed) {
                Image("MesaLogo")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 20, height: 20)
                    .clipShape(Circle())
            }
            shortcut(title: "Trips", item: "trips", sheet: .tripsList) {
                Image(systemName: "airplane")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.mesaAccent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    private func shortcut<Icon: View>(title: String, item: String, sheet: AppSheetType,
                                      @ViewBuilder icon: () -> Icon) -> some View {
        Button {
            onSelect(sheet, item)
        } label: {
            HStack(spacing: 8) {
                icon()
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
