//
//  MesaSignedInFlowTests.swift
//  locUITests
//
//  Signed-in, read-only flows against the dedicated CI test account. They XCTSkip unless
//  TEST_ACCOUNT_EMAIL / TEST_ACCOUNT_PASSWORD are in the environment (CI passes them as
//  TEST_RUNNER_TEST_ACCOUNT_EMAIL/PASSWORD from GitHub secrets). Sign-in is programmatic: the credentials are passed as
//  launch environment (UITEST_EMAIL / UITEST_PASSWORD) and the DEBUG-only LoginView hook signs in without typing. Never saves or deletes data.
//

import XCTest

final class MesaSignedInFlowTests: XCTestCase {
    private var app = XCUIApplication()
    private let timeout: TimeInterval = 30
    private let listName = "CI Test List"

    /// Skips unless credentials exist, then launches the app and signs in through the real UI.
    override func setUpWithError() throws {
        continueAfterFailure = false
        let env = ProcessInfo.processInfo.environment
        guard let email = env["TEST_ACCOUNT_EMAIL"], !email.isEmpty,
              let password = env["TEST_ACCOUNT_PASSWORD"], !password.isEmpty else {
            throw XCTSkip("TEST_ACCOUNT_EMAIL / TEST_ACCOUNT_PASSWORD not set")
        }
        addSystemAlertMonitor()
        app = XCUIApplication()
        app.launchEnvironment["UITEST_EMAIL"] = email
        app.launchEnvironment["UITEST_PASSWORD"] = password
        app.launch()
        waitForMainUI()
    }

    /// Attaches a failure screenshot when a test fails.
    override func tearDownWithError() throws {
        if let failures = testRun?.failureCount, failures > 0 {
            attachScreenshot("failure-\(name.replacingOccurrences(of: " ", with: "_"))")
        }
    }

    /// Explore tab shows city or list cards.
    func testExploreLoads() throws {
        tap(A11yID.Tab.explore)
        let content = anyMatching(ids: [A11yID.Explore.city, A11yID.Explore.list, A11yID.Explore.featured])
        XCTAssertTrue(content.waitForExistence(timeout: timeout), "No explore.city/list/featured content appeared")
        attachScreenshot("explore-loaded")
    }

    /// Opens "CI Test List" from the profile lists section and sees its places.
    func testOpenList() throws {
        try openCITestList()
        attachScreenshot("list-detail")
    }

    /// Opens the Find a table sheet from the list.
    func testFindTable() throws {
        try openCITestList()
        let find = app.descendants(matching: .any).matching(identifier: A11yID.List.findTable).firstMatch
        XCTAssertTrue(find.waitForExistence(timeout: timeout), "list.findTable button missing")
        find.tap()
        let search = app.descendants(matching: .any).matching(identifier: A11yID.List.findTableSearch).firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: timeout), "Find a table sheet did not appear")
        attachScreenshot("find-table-sheet")
        app.swipeDown(velocity: .fast)
    }

    /// Profile page shows the test user's name.
    func testProfile() throws {
        tap(A11yID.Tab.profile)
        let name = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Mesa CI Test")).firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: timeout), "Profile name 'Mesa CI Test' not shown")
        attachScreenshot("profile")
    }

    /// The Google Maps import sheet opens from the "+" menu; cancelled without importing.
    func testImportSheetOpens() throws {
        tap(A11yID.Tab.profile)
        let add = app.descendants(matching: .any).matching(identifier: A11yID.Profile.addList).firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: timeout), "profile.lists.add missing")
        add.tap()
        let importButton = app.descendants(matching: .any).matching(identifier: A11yID.Import.googleMaps).firstMatch
        XCTAssertTrue(importButton.waitForExistence(timeout: timeout), "Import from Google Maps action missing")
        let url = app.descendants(matching: .any).matching(identifier: A11yID.Import.googleMapsURL).firstMatch
        for _ in 0..<3 where !url.exists {
            // Menu items can swallow a tap while the popover is still animating; retry until the sheet opens.
            _ = importButton.waitForExistence(timeout: 5)
            if importButton.exists { importButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
            _ = url.waitForExistence(timeout: 8)
        }
        XCTAssertTrue(url.exists, "import.googleMaps.url field missing")
        attachScreenshot("import-sheet")
        let cancel = app.descendants(matching: .any).matching(identifier: A11yID.Import.cancel).firstMatch
        if cancel.exists { cancel.tap() }
    }

    // MARK: - Helpers

    /// Dismisses system permission alerts (location, notifications, contacts, tracking) when they appear.
    private func addSystemAlertMonitor() {
        addUIInterruptionMonitor(withDescription: "System permission alerts") { alert in
            for label in ["Allow While Using App", "Allow", "OK", "Ask App Not to Track", "Don\u{2019}t Allow"]
            where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }
    }

    /// Waits for the tab bar, dismissing post-login popups that cover it.
    private func waitForMainUI() {
        let tab = app.descendants(matching: .any).matching(identifier: A11yID.Tab.profile).firstMatch
        let deadline = Date().addingTimeInterval(60)
        while Date() < deadline {
            if tab.exists && tab.isHittable { return }
            dismissPopups()
            sleep(2)
        }
        attachScreenshot("main-ui-not-reached")
        XCTFail("Main tab bar did not appear after sign-in")
    }

    /// Taps common post-login dismiss buttons if present; never fails when absent.
    private func dismissPopups() {
        let ids = ["onboarding.suggested.done", "onboarding.contacts.decline", "import.photos.tooltip.dismiss", "import.cancel"]
        for id in ids {
            let button = app.descendants(matching: .any).matching(identifier: id).firstMatch
            if button.exists && button.isHittable { button.tap() }
        }
        for label in ["Not Now", "Skip", "Later", "Done", "Close", "Maybe Later"] {
            let button = app.buttons[label]
            if button.exists && button.isHittable { button.tap() }
        }
    }

    /// Taps a tab bar item by identifier.
    private func tap(_ identifier: String) {
        let tab = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: timeout), "Tab \(identifier) not found")
        tab.tap()
    }

    /// Goes to Profile, taps the "CI Test List" card, and waits for its list detail on the map.
    private func openCITestList() throws {
        tap(A11yID.Tab.profile)
        let row = app.descendants(matching: .any)
            .matching(identifier: A11yID.Profile.listRow)
            .matching(NSPredicate(format: "label CONTAINS %@", listName)).firstMatch
        let byLabel = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", listName)).firstMatch
        let target = row.waitForExistence(timeout: timeout) ? row : byLabel
        XCTAssertTrue(target.waitForExistence(timeout: 10), "'\(listName)' not found in Profile lists")
        target.tap()
        let place = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "OKONOMI")).firstMatch
        XCTAssertTrue(place.waitForExistence(timeout: timeout), "List detail with OKONOMI Brooklyn did not appear")
    }

    /// Returns a query matching any element whose identifier is in the given list.
    private func anyMatching(ids: [String]) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier IN %@", ids)).firstMatch
    }

    /// Attaches a screenshot that survives passing runs.
    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
