//
//  TripMapDaySectionHeaderView.swift
//  loc
//
//  Day section header with color dot and label for the trip map places list.
//

import SwiftUI

/// Section header showing a colored dot and day label for a trip map day group.
struct TripMapDaySectionHeaderView: View {
    let dayIndex: Int
    let dayColor: Color
    let label: String

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(dayColor)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 4)
    }
}
