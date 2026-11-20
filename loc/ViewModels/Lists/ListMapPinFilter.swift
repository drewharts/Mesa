//
//  ListMapPinFilter.swift
//  loc
//
//  Pure rule for which map pins stay visible while a list's tag chip is selected.
//  The map's own id-diff (MapIdDiff in the marker sync) then adds/removes only the pins that changed.
//

import Foundation

enum ListMapPinFilter {
    /// Keeps the annotations whose id is in `allowedIds` (case-insensitive); nil ("All") keeps everything.
    static func apply(_ annotations: [PlaceAnnotation], allowedIds: Set<String>?) -> [PlaceAnnotation] {
        guard let allowedIds else { return annotations }
        return annotations.filter { allowedIds.contains($0.id.lowercased()) }
    }
}
