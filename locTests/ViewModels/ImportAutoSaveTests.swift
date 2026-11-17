//
//  ImportAutoSaveTests.swift
//  locTests
//
//  Tests for the pure rules that save imported places straight into Saved.
//

import XCTest
@testable import loc

final class ImportAutoSaveTests: XCTestCase {

    // MARK: - Helpers

    /// Decodes a DetailPlace from the minimal JSON the app accepts, with optional extra fields.
    private func makePlace(id: String = UUID().uuidString, name: String = "Semma", extra: [String: Any] = [:]) throws -> DetailPlace {
        var json: [String: Any] = ["id": id, "name": name]
        extra.forEach { json[$0.key] = $0.value }
        let data = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(DetailPlace.self, from: data)
    }

    // MARK: - placesToSave

    func testPlacesToSave_SkipsPlaceholderAndAlreadySaved() throws {
        let fresh = try makePlace(name: "Fresh")
        let done = try makePlace(name: "Done")
        let placeholder = try makePlace(id: PlaceIdGuard.placeholderId, name: "Loading")
        let result = ImportAutoSave.placesToSave(from: [fresh, done, placeholder], alreadySaved: [done.id.uuidString])
        XCTAssertEqual(result.map(\.name), ["Fresh"])
    }

    // MARK: - bannerMessage

    func testBannerMessage_EmptyIsNil() {
        XCTAssertNil(ImportAutoSave.bannerMessage(for: []))
    }

    func testBannerMessage_SinglePlaceShowsPlacement() throws {
        let place = try makePlace(extra: ["city": "Paris", "categories": ["restaurant"]])
        XCTAssertEqual(ImportAutoSave.bannerMessage(for: [place]), "Saved to Paris · Restaurants")
    }

    func testBannerMessage_MultiplePlacesShowsCount() throws {
        let places = try (1...3).map { try makePlace(name: "P\($0)") }
        XCTAssertEqual(ImportAutoSave.bannerMessage(for: places), "Saved 3 places")
    }
}
