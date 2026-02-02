//
//  DraggablePlaceView.swift
//  loc
//
//  Drag-enabled place item for trip planning.
//

import SwiftUI
import UniformTypeIdentifiers

/// A place view that supports drag-and-drop for trip planning.
struct DraggablePlaceView: View {
    let item: TripPlaceItem
    let sourceDate: Date
    let onDragStart: () -> Void
    let onDragEnd: () -> Void

    @State private var isDragging: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            placeNumberBadge
            placeInfoView
            Spacer()
            dragIndicator
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isDragging ? Color.blue.opacity(0.1) : Color.white)
        .cornerRadius(10)
        .shadow(color: isDragging ? Color.blue.opacity(0.3) : Color.black.opacity(0.05), radius: isDragging ? 8 : 2)
        .scaleEffect(isDragging ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isDragging)
        .onDrag {
            isDragging = true
            onDragStart()
            return NSItemProvider(object: item.placeId as NSString)
        }
        .onChange(of: isDragging) { _, _ in
            // Handle drag state changes
        }
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
        }
    }

    /// Visual drag indicator.
    private var dragIndicator: some View {
        Image(systemName: "line.3.horizontal")
            .font(.body)
            .foregroundColor(.gray.opacity(0.5))
    }
}

