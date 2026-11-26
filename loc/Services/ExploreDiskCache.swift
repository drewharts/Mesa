//
//  ExploreDiskCache.swift
//  loc
//
//  Single Responsibility: persist one Codable value as JSON in the caches directory so Explore can
//  paint the previous session's results immediately and refresh in the background
//  (stale-while-revalidate).
//

import Foundation

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
