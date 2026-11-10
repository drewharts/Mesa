//
//  PlaceDataAssemblerTests.swift
//  locTests
//
//  Tests for assembling a DetailPlace from backend DTOs and merging photo URLs.
//

import XCTest
@testable import loc

final class PlaceDataAssemblerTests: XCTestCase {

    /// Decodes a BackendPlaceDTO from a JSON dictionary.
    private func decodeDTO(_ dict: [String: Any]) throws -> BackendPlaceDTO {
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(BackendPlaceDTO.self, from: data)
    }

    /// Minimal backend place JSON used by assembler tests.
    private func minimalDTOJSON(id: String = UUID().uuidString, name: String = "La Tete d'Or") -> [String: Any] {
        return [
            "id": id,
            "name": name
        ]
    }

    /// Backend photoUrls and thumbnailUrl are combined, with stored URLs ranked first.
    func testAssembleFromDTOUsesPhotoUrlsNotJustThumbnail() throws {
        var json = minimalDTOJSON()
        json["thumbnailUrl"] = "https://lh3.googleusercontent.com/p/stale=s400"
        json["photoUrls"] = [
            "https://example.supabase.co/storage/v1/object/public/places/1.jpg",
            "https://lh3.googleusercontent.com/p/other"
        ]

        let dto = try decodeDTO(json)
        let place = dto.toDetailPlace()

        XCTAssertNotNil(place)
        XCTAssertEqual(place?.photoUrls?.first?.contains("supabase.co"), true)
        XCTAssertEqual(place?.photoUrls?.count, 3)
    }

    /// Merge keeps stored photos when the overlay only has a thumbnail.
    func testMergeKeepsRicherPhotoSetFromBase() {
        var base = DetailPlace()
        base.photoUrls = ["https://example.supabase.co/storage/v1/object/public/places/1.jpg"]
        var overlay = DetailPlace()
        overlay.name = "Updated"
        overlay.photoUrls = ["https://lh3.googleusercontent.com/p/stale"]

        let merged = PlaceDataAssembler.merge(base: base, overlay: overlay)
        XCTAssertEqual(merged.name, "Updated")
        XCTAssertEqual(merged.photoUrls?.first?.contains("supabase.co"), true)
        XCTAssertEqual(merged.photoUrls?.count, 2)
    }
}
