//
//  CoverPhotoStore.swift
//  loc
//
//  Single Responsibility: persist the Explore list -> cover photo URLs map (and the order lists are
//  shown in) to the caches directory, so the next launch can paint and prefetch covers before any
//  network call returns (stale-while-revalidate).
//

import Foundation

struct CoverPhotoSnapshot: Codable {
    var covers: [String: [String]] = [:]
    /// List ids in on-screen order (featured, popular, then city covers), used to prefetch at launch.
    var displayOrder: [String] = []
}

final class CoverPhotoStore {
    static let shared = CoverPhotoStore()

    private let fileURL: URL
    private let maxEntries = 300
    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        fileURL = caches.appendingPathComponent("ExploreCoverPhotos.json")
    }

    /// Reads the last saved snapshot; empty when none exists or it cannot be decoded.
    func load() -> CoverPhotoSnapshot {
        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder().decode(CoverPhotoSnapshot.self, from: data) else { return CoverPhotoSnapshot() }
        return snapshot
    }

    /// Writes the snapshot on a background queue, keeping only the most recent entries by display order.
    func save(_ snapshot: CoverPhotoSnapshot) {
        let trimmed = trimmed(snapshot)
        DispatchQueue.global(qos: .utility).async { [fileURL] in
            guard let data = try? JSONEncoder().encode(trimmed) else { return }
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    /// Drops covers beyond the cap, keeping everything that appears in the display order first.
    private func trimmed(_ snapshot: CoverPhotoSnapshot) -> CoverPhotoSnapshot {
        guard snapshot.covers.count > maxEntries else { return snapshot }
        let keep = Set(snapshot.displayOrder).union(snapshot.covers.keys.prefix(maxEntries))
        return CoverPhotoSnapshot(covers: snapshot.covers.filter { keep.contains($0.key) }, displayOrder: snapshot.displayOrder)
    }
}
