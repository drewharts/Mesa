//
//  PhoneNumberNormalizerTests.swift
//  locTests
//
//  Tests for PhoneNumberNormalizer E.164 formatting and display formatting.
//

import XCTest
@testable import loc

final class PhoneNumberNormalizerTests: XCTestCase {

    // MARK: - normalize()

    func testNormalizeUSNumberWithoutDialCode() {
        let result = PhoneNumberNormalizer.normalize("4155551234", dialCode: "+1")
        XCTAssertEqual(result, "+14155551234")
    }

    func testNormalizeUSNumberWithDialCodeAlreadyTyped() {
        let result = PhoneNumberNormalizer.normalize("14155551234", dialCode: "+1")
        XCTAssertEqual(result, "+14155551234")
    }

    func testNormalizeFormattedNumberStripsNonDigits() {
        let result = PhoneNumberNormalizer.normalize("(415) 555-1234", dialCode: "+1")
        XCTAssertEqual(result, "+14155551234")
    }

    func testNormalizeUKNumber() {
        let result = PhoneNumberNormalizer.normalize("7911123456", dialCode: "+44")
        XCTAssertEqual(result, "+447911123456")
    }

    func testNormalizeUKNumberWithDialCodeAlreadyTyped() {
        let result = PhoneNumberNormalizer.normalize("447911123456", dialCode: "+44")
        XCTAssertEqual(result, "+447911123456")
    }

    func testNormalizeTooShortReturnsNil() {
        let result = PhoneNumberNormalizer.normalize("12345", dialCode: "+1")
        XCTAssertNil(result)
    }

    func testNormalizeExactly7DigitsSucceeds() {
        let result = PhoneNumberNormalizer.normalize("5551234", dialCode: "+1")
        XCTAssertEqual(result, "+15551234")
    }

    func testNormalizeEmptyStringReturnsNil() {
        let result = PhoneNumberNormalizer.normalize("", dialCode: "+1")
        XCTAssertNil(result)
    }

    func testNormalizeAllLettersReturnsNil() {
        let result = PhoneNumberNormalizer.normalize("abcdefgh", dialCode: "+1")
        XCTAssertNil(result)
    }

    func testNormalizeDialCodeWithPlusSign() {
        // Dial code includes "+" — normalize should handle cleaning it
        let result = PhoneNumberNormalizer.normalize("5551234567", dialCode: "+1")
        XCTAssertEqual(result, "+15551234567")
    }

    // MARK: - formatForDisplay()

    func testFormatUSNumberForDisplay() {
        let result = PhoneNumberNormalizer.formatForDisplay("+14155551234")
        XCTAssertEqual(result, "+1 (415) 555-1234")
    }

    func testFormatCanadianNumberForDisplay() {
        let result = PhoneNumberNormalizer.formatForDisplay("+16045551234")
        XCTAssertEqual(result, "+1 (604) 555-1234")
    }

    func testFormatInternationalNumberForDisplay() {
        let result = PhoneNumberNormalizer.formatForDisplay("+447911123456")
        XCTAssertEqual(result, "+447911123456")
    }

    func testFormatShortNumberForDisplay() {
        let result = PhoneNumberNormalizer.formatForDisplay("+491234")
        XCTAssertEqual(result, "+491234")
    }
}
