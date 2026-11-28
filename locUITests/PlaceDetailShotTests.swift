//
//  PlaceDetailShotTests.swift
//  locUITests
//
//  Verification screenshots for the place detail sheet layout (before/after comparison).
//  Driven by .github/workflows/screenshots.yml. Read-only: opens a place in DEBUG screenshot mode and captures it.
//

import XCTest

final class PlaceDetailShotTests: XCTestCase {
    private let placeId = "62880881-793E-4D42-8094-F9E1C7EFD353"

    override func setUpWithError() throws {
        continueAfterFailure = true
        addUIInterruptionMonitor(withDescription: "System alerts") { alert in
            for label in ["Allow While Using App", "Allow", "OK", "Don\u{2019}t Allow", "Not Now"]
            where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }
    }

    func testPlaceDetailLayout() throws {
        let env = ProcessInfo.processInfo.environment
        let app = XCUIApplication()
        app.launchArguments += ["-MesaScreenshotMode", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment["MESA_SCREENSHOT_SCENE"] = "place:\(placeId):Genki Omakase"
        app.launchEnvironment["MESA_DEMO_EMAIL"] = env["MESA_DEMO_EMAIL"] ?? ""
        app.launchEnvironment["MESA_DEMO_PASSWORD"] = env["MESA_DEMO_PASSWORD"] ?? ""
        app.launch()
        waitForScene(in: app)
        sleep(6)
        waitForImages(in: app)
        attach("01_initial", app: app)

        let handle = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.715))
        handle.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)))
        sleep(3)
        waitForImages(in: app)
        attach("02_expanded", app: app)
        sleep(2)

        let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.80))
        from.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)))
        sleep(3)
        waitForImages(in: app)
        attach("03_scrolled", app: app)
        app.terminate()
    }

    private func attach(_ name: String, app: XCUIApplication) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
        let diag = XCTAttachment(string: "\(name) \(readiness(in: app) ?? "no probe")")
        diag.name = "diag_\(name)"
        diag.lifetime = .keepAlways
        add(diag)
    }

    private func readiness(in app: XCUIApplication) -> String? {
        let probe = app.descendants(matching: .any).matching(identifier: "screenshot.ready").firstMatch
        return probe.exists ? probe.value as? String : nil
    }

    private func isLoading(_ app: XCUIApplication) -> Bool {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH[c] 'Loading'")).count > 0
    }

    private func waitForScene(in app: XCUIApplication) {
        let deadline = Date().addingTimeInterval(150)
        var idle = 0
        while Date() < deadline {
            if let value = readiness(in: app) {
                let ready = value.contains("scene=place") && value.contains("shimmer=0") && value.contains("images=1")
                    && value.contains("pfp=1") && !isLoading(app)
                idle = ready ? idle + 1 : 0
                if idle >= 3 { return }
            }
            sleep(2)
        }
    }

    private func waitForImages(in app: XCUIApplication, timeout: TimeInterval = 90) {
        let deadline = Date().addingTimeInterval(timeout)
        var stable = 0
        while Date() < deadline {
            let ok = (readiness(in: app) ?? "").contains("images=1") && !isLoading(app)
            stable = ok ? stable + 1 : 0
            if stable >= 3 { return }
            sleep(1)
        }
    }
}
