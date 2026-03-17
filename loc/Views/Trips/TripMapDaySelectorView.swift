//
//  TripMapDaySelectorView.swift
//  loc
//
//  Horizontal day filter pills for the trip map sheet
//

import SwiftUI

/// Horizontal scroll of day pills to filter the trip map by day.
struct TripMapDaySelectorView: View {
    @ObservedObject var viewModel: TripMapViewModel

    private let mesaCharcoal = Color(red: 45/255, green: 45/255, blue: 45/255)

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                allPill
                ForEach(viewModel.dayIndices, id: \.self) { index in
                    let isSelected = viewModel.selectedDayFilter == index
                    let dayColor = TripMapViewModel.colorForDay(index)

                    Button {
                        viewModel.selectDayFilter(index)
                    } label: {
                        Text(viewModel.shortDayLabel(for: index))
                            .font(.subheadline)
                            .fontWeight(isSelected ? .semibold : .regular)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(isSelected ? dayColor : Color(.systemGray6))
                            .foregroundStyle(isSelected ? .white : .primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    /// "All" pill showing all days on the map.
    private var allPill: some View {
        Button {
            viewModel.selectDayFilter(nil)
        } label: {
            Text("All")
                .font(.subheadline)
                .fontWeight(viewModel.selectedDayFilter == nil ? .semibold : .regular)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(viewModel.selectedDayFilter == nil ? mesaCharcoal : Color(.systemGray6))
                .foregroundStyle(viewModel.selectedDayFilter == nil ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
