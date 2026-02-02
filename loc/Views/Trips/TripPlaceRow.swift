//
//  TripPlaceRow.swift
//  loc
//
//  Row view for a place within a trip day.
//

import SwiftUI

/// Displays a single place row within a trip day.
struct TripPlaceRow: View {
    let item: TripPlaceItem
    let isEditing: Bool
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if isEditing {
                deleteButton
            }

            placeNumberBadge
            placeInfoView

            Spacer()

            if isEditing {
                dragHandle
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.white)
        .contentShape(Rectangle())
    }

    /// Delete button for edit mode.
    private var deleteButton: some View {
        Button(action: onRemove) {
            Image(systemName: "minus.circle.fill")
                .font(.title3)
                .foregroundColor(.red)
        }
        .buttonStyle(.plain)
    }

    /// Order number badge.
    private var placeNumberBadge: some View {
        Text("\(item.sortOrder + 1)")
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .frame(width: 24, height: 24)
            .background(Color.blue)
            .clipShape(Circle())
    }

    /// Place name and address info.
    private var placeInfoView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.placeName)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.black)
                .lineLimit(1)

            if !item.placeAddress.isEmpty {
                Text(item.placeAddress)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }

            if let notes = item.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.blue)
                    .lineLimit(1)
            }
        }
    }

    /// Drag handle for reordering.
    private var dragHandle: some View {
        Image(systemName: "line.3.horizontal")
            .font(.title3)
            .foregroundColor(.gray)
    }
}
