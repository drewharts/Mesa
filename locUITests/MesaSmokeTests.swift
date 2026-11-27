//
//  MesaSmokeTests.swift
//  locUITests
//
//  Signed-out smoke test: the app launches and renders the sign-in screen. Screenshots are kept
//  as xcresult attachments so CI can export them (artifact `smoke-screenshots`).
//

import XCTest

final class MesaSmokeTests: XCTestCase {
    private let launchTimeout: TimeInterval = 45

    /// Stops at the first failure so the screenshot reflects the broken state.
    override func setUpWithError() throws {
        continueAfterFailure = false
        addUIInterruptionMonitor(withDescription: "System permission alerts") { alert in
            for label in ["Allow While Using App", "Allow", "OK", "Don\u{2019}t Allow"] where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }
    }

    /// Launches the app signed-out and asserts the sign-in screen renders.
    func testSignedOutShowsSignInScreen() throws {
        let app = XCUIApplication()
        app.launch()
        attachScreenshot(of: app, named: "01-launch")

        let signInButtons = app.buttons.matching(NSPredicate(
            format: "identifier == %@ OR label == %@", A11yID.Auth.signInGoogle, A11yID.Label.continueWithGoogle))
        let title = app.staticTexts[A11yID.Label.signedOutTitle]
        let appeared = signInButtons.firstMatch.waitForExistence(timeout: launchTimeout)
            || title.waitForExistence(timeout: 5)
        app.tap() // lets the interruption monitor dismiss any pending permission alert
        attachScreenshot(of: app, named: "02-sign-in-screen")
        XCTAssertTrue(appeared, "Sign-in screen (Get Started / Continue with Google) did not render within \(launchTimeout)s")
    }

    /// Attaches a screenshot that survives passing runs (lifetime keepAlways).
    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
