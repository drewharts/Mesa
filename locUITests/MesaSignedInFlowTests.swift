//
//  MesaSignedInFlowTests.swift
//  locUITests
//
//  Signed-in smoke flows. They XCTSkip unless TEST_ACCOUNT_EMAIL and TEST_ACCOUNT_PASSWORD are in the
//  environment (CI passes them as TEST_RUNNER_TEST_ACCOUNT_EMAIL/..., derived from the TEST_ACCOUNT secret),
//  and unless the sign-in screen offers email/password fields (the shipping app only has Apple/Google
//  sign-in, so these skip until a test-account sign-in path exists; no auth bypass lives in the app).
//

import XCTest

final class MesaSignedInFlowTests: XCTestCase {
    private var app = XCUIApplication()
    private let timeout: TimeInterval = 30

    /// Skips unless credentials exist, then launches the app and signs in through the real UI.
    override func setUpWithError() throws {
        continueAfterFailure = false
        let env = ProcessInfo.processInfo.environment
        guard let email = env["TEST_ACCOUNT_EMAIL"], !email.isEmpty,
              let password = env["TEST_ACCOUNT_PASSWORD"], !password.isEmpty else {
            throw XCTSkip("TEST_ACCOUNT_EMAIL / TEST_ACCOUNT_PASSWORD not set")
        }
        app = XCUIApplication()
        app.launch()
        try signIn(email: email, password: password)
    }

    /// Explore tab loads after sign-in.
    func testExploreLoads() throws {
        try openTab(A11yID.Tab.explore, label: A11yID.Label.explore)
        attachScreenshot("explore")
    }

    /// Opens the first list card from Explore.
    func testOpenList() throws {
        try openTab(A11yID.Tab.explore, label: A11yID.Label.explore)
        let card = app.scrollViews.descendants(matching: .button).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: timeout), "No list card appeared on Explore")
        card.tap()
        attachScreenshot("list-detail")
    }

    /// Opens "Find a table" from a list.
    func testFindTable() throws {
        try openFirstListAndTapFindTable()
    }

    /// Profile tab loads.
    func testProfile() throws {
        try openTab(A11yID.Tab.profile, label: A11yID.Label.profile)
        attachScreenshot("profile")
    }

    /// The Google Maps import sheet opens from the list actions menu.
    func testImportSheetOpens() throws {
        try openTab(A11yID.Tab.profile, label: A11yID.Label.profile)
        let add = app.buttons[A11yID.Profile.addList]
        XCTAssertTrue(add.waitForExistence(timeout: timeout), "profile.lists.add missing")
        add.tap()
        let importButton = element(A11yID.Import.googleMaps, label: A11yID.Label.importGoogleMaps)
        XCTAssertTrue(importButton.waitForExistence(timeout: timeout), "Import from Google Maps action missing")
        importButton.tap()
        attachScreenshot("import-sheet")
    }

    // MARK: - Helpers

    /// Enters credentials in the sign-in screen's email/password fields, skipping if they don't exist.
    private func signIn(email: String, password: String) throws {
        let emailField = app.textFields[A11yID.Auth.email]
        guard emailField.waitForExistence(timeout: timeout) else {
            throw XCTSkip("Sign-in screen has no email/password fields (\(A11yID.Auth.email))")
        }
        emailField.tap()
        emailField.typeText(email)
        let passwordField = app.secureTextFields[A11yID.Auth.password]
        passwordField.tap()
        passwordField.typeText(password)
        app.buttons[A11yID.Auth.signIn].tap()
    }

    /// Taps a tab by identifier, falling back to its visible label.
    private func openTab(_ identifier: String, label: String) throws {
        let tab = element(identifier, label: label)
        XCTAssertTrue(tab.waitForExistence(timeout: timeout), "Tab \(identifier) not found")
        tab.tap()
    }

    /// Opens a list from Explore and taps "Find a table".
    private func openFirstListAndTapFindTable() throws {
        try openTab(A11yID.Tab.explore, label: A11yID.Label.explore)
        let card = app.scrollViews.descendants(matching: .button).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: timeout))
        card.tap()
        let find = element(A11yID.List.findTable, label: A11yID.Label.findTable)
        XCTAssertTrue(find.waitForExistence(timeout: timeout), "Find a table button missing")
        find.tap()
        attachScreenshot("find-table")
    }

    /// Returns the element with the identifier if present, otherwise the one with the label.
    private func element(_ identifier: String, label: String) -> XCUIElement {
        let byId = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        return byId.exists ? byId : app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    /// Attaches a screenshot that survives passing runs.
    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
