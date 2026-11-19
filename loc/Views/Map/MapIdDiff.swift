//
//  MapIdDiff.swift
//  loc
//
//  Set difference between the ids currently on the map and the incoming ids, so annotation
//  updates only touch markers that were actually added or removed.
//

struct MapIdDiff: Equatable {
    let removed: Set<String>
    let added: Set<String>
    let kept: Set<String>

    /// True when nothing was added or removed.
    var isEmpty: Bool { removed.isEmpty && added.isEmpty }

    /// Computes which ids were removed, added, and kept going from `old` to `new`.
    init(old: Set<String>, new: Set<String>) {
        removed = old.subtracting(new)
        added = new.subtracting(old)
        kept = old.intersection(new)
    }
}
