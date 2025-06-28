//
//  PlaceTypeFilterButtonsView.swift
//  loc
//
//  Created by Assistant on 1/9/25.
//

import SwiftUI

struct PlaceTypeFilterButtonsView: View {
    @ObservedObject var filterVM: PlaceTypeFilterViewModel
    
    var body: some View {
        VStack(spacing: 8) {
            // Filter status indicator
            if filterVM.isFiltering {
                HStack {
                    Text("Showing: \(filterVM.selectedTypesDisplayText)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Clear All") {
                        filterVM.clearAllFilters()
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
                .padding(.horizontal, 20)
            }
            
            // Loading state or filter buttons
            if filterVM.isCalculatingTypes && filterVM.mostFrequentTypes.isEmpty {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading filters...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // Most frequent type buttons
                        ForEach(filterVM.mostFrequentTypes, id: \.self) { type in
                            PlaceTypeButton(
                                type: type,
                                isSelected: filterVM.selectedPlaceTypes.contains(type),
                                action: {
                                    filterVM.togglePlaceType(type)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}

struct PlaceTypeButton: View {
    let type: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(type)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .cornerRadius(16)
        }
    }
}
