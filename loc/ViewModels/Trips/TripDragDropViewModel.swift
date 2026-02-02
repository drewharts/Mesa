//
//  TripDragDropViewModel.swift
//  loc
//
//  ViewModel for managing drag-and-drop state in trip planning.
//

import SwiftUI
import UniformTypeIdentifiers

/// Manages drag-and-drop state for trip place management.
@MainActor
class TripDragDropViewModel: ObservableObject {
    // MARK: - Published Properties

    /// ID of the place currently being dragged.
    @Published var draggingPlaceId: String?

    /// Source date of the dragging place.
    @Published var dragSourceDate: Date?

    /// Target date for drop preview.
    @Published var dropTargetDate: Date?

    /// Whether a drag operation is in progress.
    @Published var isDragging: Bool = false

    // MARK: - Drag Operations

    /// Starts a drag operation for a place.
    func beginDrag(placeId: String, fromDate: Date) {
        draggingPlaceId = placeId
        dragSourceDate = fromDate
        isDragging = true
    }

    /// Updates the current drop target.
    func updateDropTarget(date: Date?) {
        dropTargetDate = date
    }

    /// Ends the drag operation.
    func endDrag() {
        draggingPlaceId = nil
        dragSourceDate = nil
        dropTargetDate = nil
        isDragging = false
    }

    /// Returns whether a place is currently being dragged.
    func isPlaceBeingDragged(placeId: String) -> Bool {
        draggingPlaceId == placeId && isDragging
    }

    /// Returns whether a date is the current drop target.
    func isDropTarget(date: Date) -> Bool {
        guard let targetDate = dropTargetDate else { return false }
        return Calendar.current.isDate(targetDate, inSameDayAs: date)
    }

    /// Returns whether a date is the drag source.
    func isDragSource(date: Date) -> Bool {
        guard let sourceDate = dragSourceDate else { return false }
        return Calendar.current.isDate(sourceDate, inSameDayAs: date)
    }

    // MARK: - Drag Provider

    /// Creates an NSItemProvider for drag operations.
    func createDragProvider(placeId: String) -> NSItemProvider {
        let provider = NSItemProvider(object: placeId as NSString)
        return provider
    }

    /// Creates drag preview for a place.
    func createDragPreview(placeName: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "mappin.circle.fill")
                .foregroundColor(.red)
            Text(placeName)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white)
        .cornerRadius(8)
        .shadow(radius: 4)
    }

    // MARK: - Drop Handling

    /// Validates a drop operation.
    func validateDrop(items: [NSItemProvider], date: Date) -> Bool {
        // Check if any item is a string (place ID)
        items.contains { $0.hasItemConformingToTypeIdentifier(UTType.text.identifier) }
    }

    /// Performs a drop operation.
    func performDrop(items: [NSItemProvider], targetDate: Date) async -> String? {
        for item in items {
            if item.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                do {
                    if let data = try await item.loadItem(forTypeIdentifier: UTType.text.identifier) as? Data,
                       let placeId = String(data: data, encoding: .utf8) {
                        return placeId
                    }
                    if let placeId = try await item.loadItem(forTypeIdentifier: UTType.text.identifier) as? String {
                        return placeId
                    }
                } catch {
                    print("❌ [TripDragDropViewModel] Failed to load drop item: \(error)")
                }
            }
        }
        return nil
    }
}

// MARK: - UTType Extension for Drag Types

extension UTType {
    static let tripPlace = UTType(exportedAs: "com.mesa.trip.place")
}
