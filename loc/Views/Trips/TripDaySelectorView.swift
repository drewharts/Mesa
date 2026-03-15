//
//  TripDaySelectorView.swift
//  loc
//
//  Horizontal day selector pills for trip detail
//

import SwiftUI

/// Horizontal ScrollView of day pills for selecting which day to view.
struct TripDaySelectorView: View {
    let dayIndices: [Int]
    @Binding var selectedDayIndex: Int
    let dayLabel: (Int) -> String

    /// Optional callback when a dragged place is dropped onto a day pill.
    var onDropPlace: ((String, Int) -> Void)?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(dayIndices, id: \.self) { index in
                    TripDayPillView(
                        index: index,
                        isSelected: selectedDayIndex == index,
                        label: dayLabel(index),
                        onSelect: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedDayIndex = index
                            }
                        },
                        onDropPlace: onDropPlace
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
}
