//
//  FoldedListsStore.swift
//  loc
//
//  Remembers, per user and on this device only, which lists were folded into their cities and which
//  the user brought back. Nothing is written to the backend and no list is ever deleted: folding only
//  hides a list from the main lists UI. Unit tested in FoldedListsStoreTests.
//

import Foundation

struct FoldedListsStore {
    private let defaults: UserDefaults
    private let userId: String

    /// Creates a store scoped to one user (ids are lowercased so the key never depends on casing).
    init(userId: String, defaults: UserDefaults = .standard) {
        self.userId = userId.lowercased()
        self.defaults = defaults
    }

    /// Ids of the lists currently folded away.
    var foldedIds: Set<String> { read("folded") }

    /// Ids the user brought back with Undo / Restore; detection never folds these again.
    var declinedIds: Set<String> { read("declined") }

    /// Folds the given lists (ids the user declined are skipped). Returns the ids that were newly folded.
    @discardableResult
    func fold(_ ids: [String]) -> [String] {
        let declined = declinedIds
        let current = foldedIds
        let fresh = ids.map { $0.lowercased() }.filter { !declined.contains($0) && !current.contains($0) }
        write("folded", current.union(fresh))
        return fresh
    }

    /// Brings the given lists back and remembers the user wanted them visible.
    func restore(_ ids: [String]) {
        let lowered = Set(ids.map { $0.lowercased() })
        write("folded", foldedIds.subtracting(lowered))
        write("declined", declinedIds.union(lowered))
    }

    /// Whether the list is folded.
    func isFolded(_ id: String) -> Bool { foldedIds.contains(id.lowercased()) }

    /// Forgets folded ids whose list no longer exists (deleted elsewhere), so the count stays honest.
    func prune(keeping existing: Set<String>) {
        let lowered = Set(existing.map { $0.lowercased() })
        write("folded", foldedIds.intersection(lowered))
    }

    // MARK: - Private

    /// Reads one stored id set.
    private func read(_ name: String) -> Set<String> {
        Set(defaults.stringArray(forKey: key(name)) ?? [])
    }

    /// Writes one stored id set (sorted so the stored value is stable).
    private func write(_ name: String, _ ids: Set<String>) {
        defaults.set(ids.sorted(), forKey: key(name))
    }

    /// UserDefaults key for one stored set, scoped to the user.
    private func key(_ name: String) -> String { "cityFold.\(name).\(userId)" }
}
