//
//  PlaceDropTargetView.swift
//  loc
//
//  Drop target view for receiving dragged places in trip planning.
//

import SwiftUI

/// A view that can receive dropped places.
struct PlaceDropTargetView: View {
    let date: Date
    let isActive: Bool
    let onDrop: (String) -> Void

    var body: some View {
        Rectangle()
            .fill(isActive ? Color.blue.opacity(0.2) : Color.clear)
            .frame(height: isActive ? 60 : 20)
            .overlay(dropHintOverlay)
            .cornerRadius(8)
            .animation(.easeInOut(duration: 0.2), value: isActive)
            .dropDestination(for: String.self) { items, _ in
                guard let placeId = items.first else { return false }
                onDrop(placeId)
                return true
            } isTargeted: { _ in }
    }

    /// Overlay showing drop hint when active.
    @ViewBuilder
    private var dropHintOverlay: some View {
        if isActive {
            HStack {
                Image(systemName: "plus.circle")
                Text("Drop here")
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
    }
}
