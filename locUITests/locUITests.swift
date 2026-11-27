//
//  locUITests.swift
//  locUITests
//
//  Created by Andrew Hartsfield II on 7/13/24.
//

import XCTest

final class locUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}

/// App Store screenshot capture. Driven by .github/workflows/screenshots.yml.
/// Each scene relaunches the app in DEBUG screenshot mode; the app signs in the demo account
/// (env from CI secrets), opens the scene itself and reports loading state through the hidden
/// `screenshot.ready` element. Screenshots are kept as XCTAttachments named "NN_scene" and
/// exported from the .xcresult by the workflow. Read-only: it never writes app data.
final class ScreenshotTests: XCTestCase {
    private struct Scene {
        let name: String
        let launch: String
        /// Accessibility identifiers or labels (any one) that prove the scene's real content is on screen.
        let markers: [String]
    }

    private let listId = "389894C6-3EE7-49D1-8D10-86DCAE238B7D"
    private let placeId = "62880881-793E-4D42-8094-F9E1C7EFD353"
    private let tripId = "441B0184-F0BE-4DFB-8F23-C5B70CD5A385"

    private var scenes: [Scene] {
        let only = ProcessInfo.processInfo.environment["SCREENSHOT_ONLY"] ?? ""
        let all = [
            Scene(name: "01_map", launch: "list:\(listId)", markers: ["list.findTable"]),
            Scene(name: "02_explore", launch: "explore", markers: ["explore.city", "explore.list"]),
            Scene(name: "03_list", launch: "list:\(listId)", markers: ["list.findTable"]),
            Scene(name: "04_place", launch: "place:\(placeId):Genki Omakase", markers: ["Genki Omakase"]),
            Scene(name: "05_trips", launch: "trips:\(tripId)", markers: ["Summer nyc 2026"]),
            Scene(name: "06_profile", launch: "profile", markers: ["profile.name"]),
            Scene(name: "07_tonight", launch: "tonight", markers: [])
        ]
        guard !only.isEmpty else { return all }
        return all.filter { only.contains($0.name.prefix(2)) }
    }

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

    func testCaptureAppStoreScreenshots() throws {
        let env = ProcessInfo.processInfo.environment
        for scene in scenes {
            let app = XCUIApplication()
            app.launchArguments += ["-MesaScreenshotMode", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
            app.launchEnvironment["MESA_SCREENSHOT_SCENE"] = scene.launch
            app.launchEnvironment["MESA_DEMO_EMAIL"] = env["MESA_DEMO_EMAIL"] ?? ""
            app.launchEnvironment["MESA_DEMO_PASSWORD"] = env["MESA_DEMO_PASSWORD"] ?? ""
            app.launch()
            let summary = waitForScene(scene, in: app)
            sleep(UInt32(env["SCREENSHOT_SETTLE_SECONDS"] ?? "5") ?? 5)
            if scene.name == "01_map" || scene.name == "03_list" { sleep(12) } // pins load after the list's places
            if scene.name == "01_map" { zoomMap(in: app) }
            if scene.name == "02_explore" { captureExploreCities(in: app, summary: summary) }
            if scene.name == "04_place" { dragSheetUp(in: app) }
            let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            shot.name = scene.name
            shot.lifetime = .keepAlways
            add(shot)
            let diag = XCTAttachment(string: "\(scene.name) \(readiness(in: app) ?? summary)")
            diag.name = "diag_\(scene.name)"
            diag.lifetime = .keepAlways
            add(diag)
            app.terminate()
        }
    }

    /// Scrolls Explore so the city covers show, waits for them, and attaches an extra "02b" screenshot; scrolls back up.
    private func captureExploreCities(in app: XCUIApplication, summary: String) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.80))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.50))
        start.press(forDuration: 0.1, thenDragTo: end)
        sleep(10)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "02b_explore_cities"
        shot.lifetime = .keepAlways
        add(shot)
        let back = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.40))
        back.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)))
        sleep(3)
    }

    /// Double-taps the visible map twice (Midtown/Union Square area) so individual pins show instead of wide clusters.
    private func zoomMap(in app: XCUIApplication) {
        let spot = app.coordinate(withNormalizedOffset: CGVector(dx: 0.38, dy: 0.22))
        spot.doubleTap()
        sleep(3)
        spot.doubleTap()
        sleep(8)
    }

    /// Drags the place sheet up from its handle so the place photos are visible.
    private func dragSheetUp(in app: XCUIApplication) {
        let handle = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.715))
        handle.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)))
        sleep(8)
    }

    /// Reads the app's hidden readiness value ("scene=..;shimmer=..;pfp=..;note=..").
    private func readiness(in app: XCUIApplication) -> String? {
        let probe = app.descendants(matching: .any).matching(identifier: "screenshot.ready").firstMatch
        return probe.exists ? probe.value as? String : nil
    }

    /// Waits until the app opened the scene, its content is visible, placeholders are gone and the profile photo loaded.
    private func waitForScene(_ scene: Scene, in app: XCUIApplication) -> String {
        let deadline = Date().addingTimeInterval(150)
        var last = "no readiness probe"
        var recentered = false
        var idlePolls = 0
        while Date() < deadline {
            if scene.name.hasSuffix("map"), !recentered {
                let recenter = app.buttons["map.recenter"]
                if recenter.exists && recenter.isHittable { recenter.tap(); recentered = true }
            }
            if let value = readiness(in: app) {
                last = value
                let opened = value.contains("scene=\(scene.launch.split(separator: ":").first ?? "")")
                let ready = opened && value.contains("shimmer=0") && value.contains("pfp=1") && hasContent(scene, in: app) && !isLoading(app)
                idlePolls = ready ? idlePolls + 1 : 0
                if idlePolls >= 3 { return last }
            }
            sleep(2)
        }
        return last
    }

    /// True when one of the scene's marker identifiers or labels exists (always true when the scene has none).
    private func hasContent(_ scene: Scene, in app: XCUIApplication) -> Bool {
        if scene.markers.isEmpty { return true }
        return scene.markers.contains { marker in
            app.descendants(matching: .any).matching(identifier: marker).firstMatch.exists
                || app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", marker)).firstMatch.exists
        }
    }

    /// True while any visible text starts with "Loading".
    private func isLoading(_ app: XCUIApplication) -> Bool {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH[c] 'Loading'")).count > 0
    }
}
