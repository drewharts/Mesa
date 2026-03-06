//
//  CityGroupHeaderView.swift
//  loc
//
//  DUMB Component: Collapsible city section header for grouped lists.
//  Single Responsibility: Render a tappable header with city name, count, and chevron.
//

import SwiftUI

struct CityGroupHeaderView: View {
    let city: String
    let listCount: Int
    let isCollapsed: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(city)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("\(listCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                    .animation(.easeInOut(duration: 0.2), value: isCollapsed)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
