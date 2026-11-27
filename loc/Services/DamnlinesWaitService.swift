//
//  DamnlinesWaitService.swift
//  loc
//
//  Fetches and caches the public damnlines.com line index (CC BY 4.0, attribution required).
//

import Foundation

final class DamnlinesWaitService {
    static let shared = DamnlinesWaitService()

    static let indexURL = URL(string: "https://damnlines.com/data/line-index")!
    private static let cacheKey = "damnlines.lineIndex.v1"
    private static let cacheDateKey = "damnlines.lineIndex.v1.date"
    private static let maxAge: TimeInterval = 3600

    private let session: URLSession
    private let defaults: UserDefaults
    private var memory: (data: Data, date: Date)?
    private let lock = NSLock()

    /// Creates a service with injectable networking and storage for tests.
    init(session: URLSession = .shared, defaults: UserDefaults = .standard) {
        self.session = session
        self.defaults = defaults
    }

    /// Returns wait info for a Mesa place id, or nil when unmapped or the index cannot be loaded.
    func waitInfo(forPlaceId placeId: String) async -> DamnlinesWaitInfo? {
        guard let slug = DamnlinesPlaceMap.slug(forPlaceId: placeId),
              let data = await indexData() else { return nil }
        return Self.parse(data, slug: slug)
    }

    /// Parses index JSON and returns the venue whose page URL ends in the slug; nil on any failure.
    static func parse(_ data: Data, slug: String) -> DamnlinesWaitInfo? {
        guard let index = try? JSONDecoder().decode(DamnlinesLineIndex.self, from: data),
              let venue = index.venues.first(where: { URL(string: $0.page)?.lastPathComponent == slug }),
              let url = URL(string: venue.page), url.scheme == "https" else { return nil }
        return DamnlinesWaitInfo(
            venueName: venue.venue,
            averageWaitMinutes: venue.averageWaitMinutes,
            peakWaitMinutes: venue.peak.waitMinutes,
            peakDay: venue.peak.day,
            peakHourLocal: venue.peak.hourLocal,
            pageURL: url
        )
    }

    /// Returns fresh cached index bytes (memory, then disk) or fetches and caches them.
    private func indexData() async -> Data? {
        if let cached = cachedData() { return cached }
        guard let (data, response) = try? await session.data(from: Self.indexURL),
              (response as? HTTPURLResponse)?.statusCode == 200,
              (try? JSONDecoder().decode(DamnlinesLineIndex.self, from: data)) != nil else { return nil }
        store(data)
        return data
    }

    /// Returns cached bytes younger than the max age, preferring memory over disk.
    private func cachedData() -> Data? {
        lock.lock(); defer { lock.unlock() }
        if let memory, Date().timeIntervalSince(memory.date) < Self.maxAge { return memory.data }
        guard let data = defaults.data(forKey: Self.cacheKey),
              let date = defaults.object(forKey: Self.cacheDateKey) as? Date,
              Date().timeIntervalSince(date) < Self.maxAge else { return nil }
        memory = (data, date)
        return data
    }

    /// Stores index bytes in memory and UserDefaults with the current timestamp.
    private func store(_ data: Data) {
        lock.lock(); defer { lock.unlock() }
        let now = Date()
        memory = (data, now)
        defaults.set(data, forKey: Self.cacheKey)
        defaults.set(now, forKey: Self.cacheDateKey)
    }
}
