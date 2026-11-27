//
//  ExploreDiskCache.swift
//  loc
//
//  Single Responsibility: persist one Codable value as JSON in the caches directory so Explore can
//  paint the previous session's results immediately and refresh in the background
//  (stale-while-revalidate).
//

import Foundation

/// Version of the cached Explore covers; bump to discard every persisted cover/Explore snapshot once.
enum ExploreCacheVersion {
    static let coverCacheVersion = 2
    private static let defaultsKey = "exploreCoverCacheVersion"
    private static let fileNames = ["ExploreCoverPhotos.json", "ExploreLists.json", "ExploreSuggestedPeople.json"]

    /// Deletes the persisted Explore cache files the first time a newer cache version runs; evaluated once per process.
    static let migrated: Bool = {
        guard UserDefaults.standard.integer(forKey: defaultsKey) < coverCacheVersion else { return true }
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        fileNames.forEach { try? FileManager.default.removeItem(at: caches.appendingPathComponent($0)) }
        UserDefaults.standard.set(coverCacheVersion, forKey: defaultsKey)
        return true
    }()
}

struct ExploreListsSnapshot: Codable {
    var popularLists: [ExploreList]
    var popularTitle: String
    var cities: [ExploreCity]
    var cityCoverListIds: [String: [String]]
}

struct ExploreDiskCache<Value: Codable> {
    private let fileURL: URL

    /// Creates a cache backed by `Caches/<fileName>`.
    init(fileName: String) {
        _ = ExploreCacheVersion.migrated
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        fileURL = caches.appendingPathComponent(fileName)
    }

    /// Reads the saved value; nil when none exists or it cannot be decoded (e.g. the model changed).
    func load() -> Value? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(Value.self, from: data)
    }

    /// Writes the value atomically on a background queue; failures are ignored (it is only a cache).
    func save(_ value: Value) {
        DispatchQueue.global(qos: .utility).async { [fileURL] in
            guard let data = try? JSONEncoder().encode(value) else { return }
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
