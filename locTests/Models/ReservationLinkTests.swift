//
//  ReservationLinkTests.swift
//  locTests
//
//  Tests for ReservationLink decoding, provider labels, and URL validation.
//

import XCTest
@testable import loc

final class ReservationLinkTests: XCTestCase {

    private func decode(_ json: String) throws -> ReservationLink {
        try JSONDecoder().decode(ReservationLink.self, from: Data(json.utf8))
    }

    func testDecodeResy() throws {
        let link = try decode(#"{"provider":"resy","url":"https://resy.com/cities/ny/foo"}"#)
        XCTAssertEqual(link.buttonTitle, "Reserve on Resy")
        XCTAssertNotNil(link.destinationURL)
    }

    func testDecodeNullsHasNoDestination() throws {
        let link = try decode(#"{"provider":null,"url":null}"#)
        XCTAssertNil(link.destinationURL)
        XCTAssertEqual(link.buttonTitle, "Reserve")
    }

    func testDecodeEmptyObject() throws {
        XCTAssertNil(try decode("{}").destinationURL)
    }

    func testProviderLabels() {
        XCTAssertEqual(ReservationLink.providerDisplayName("OpenTable"), "OpenTable")
        XCTAssertEqual(ReservationLink.providerDisplayName("tock"), "Tock")
        XCTAssertEqual(ReservationLink.providerDisplayName("sevenrooms"), "SevenRooms")
        XCTAssertNil(ReservationLink.providerDisplayName("somethingelse"))
        XCTAssertNil(ReservationLink.providerDisplayName(nil))
    }

    func testProviderLogoAssetNames() {
        XCTAssertEqual(ReservationLink.providerLogoAssetName("resy"), "ReserveLogoResy")
        XCTAssertEqual(ReservationLink.providerLogoAssetName("OpenTable"), "ReserveLogoOpenTable")
        XCTAssertEqual(ReservationLink.providerLogoAssetName("tock"), "ReserveLogoTock")
        XCTAssertEqual(ReservationLink.providerLogoAssetName("Seven Rooms"), "ReserveLogoSevenRooms")
        XCTAssertEqual(ReservationLink.providerLogoAssetName("yelp"), "ReserveLogoYelp")
        XCTAssertNil(ReservationLink.providerLogoAssetName("somethingelse"))
        XCTAssertNil(ReservationLink.providerLogoAssetName(nil))
    }

    func testButtonLabelTextAndLogo() throws {
        let resy = try decode(#"{"provider":"resy","url":"https://resy.com/x"}"#)
        XCTAssertEqual(resy.buttonLabelText, "Reserve · Resy")
        XCTAssertEqual(resy.logoAssetName, "ReserveLogoResy")
        let unknown = try decode(#"{"provider":"foo","url":"https://x.com"}"#)
        XCTAssertEqual(unknown.buttonLabelText, "Reserve")
        XCTAssertNil(unknown.logoAssetName)
    }

    func testNonHttpURLRejected() throws {
        XCTAssertNil(try decode(#"{"provider":"resy","url":"javascript:alert(1)"}"#).destinationURL)
    }

    func testReservableCategory() {
        XCTAssertTrue(ReservationLink.isReservableCategory(["Italian Restaurant"]))
        XCTAssertFalse(ReservationLink.isReservableCategory(["Park"]))
        XCTAssertFalse(ReservationLink.isReservableCategory(nil))
    }
}
