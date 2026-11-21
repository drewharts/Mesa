//
//  ImportAutoSaveTests.swift
//  locTests
//
//  Tests for the pure rules that save imported places straight into their city list.
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
}
