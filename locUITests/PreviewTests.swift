//
//  PreviewTests.swift
//  locUITests
//
//  App Store PREVIEW VIDEO choreography. Driven by .github/workflows/previews.yml, which records the
//  simulator screen around each test. Every test launches in DEBUG screenshot mode, waits until the
//  starting scene is fully loaded, prints `PREVIEW_MARK start <name> <epoch>`, performs slow, paced
//  interactions, prints `PREVIEW_MARK end <name> <epoch>` and holds one second. Read-only: it never books anything.
//

import XCTest

final class PreviewTests: XCTestCase {
    private let listId = "389894C6-3EE7-49D1-8D10-86DCAE238B7D"

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

    // MARK: - Previews

    /// Map with the list's pins and sheet: scroll the list a little, open a place, pull its sheet up to show photos.
    func testPreviewMap() throws {
        let app = launch(scene: "listpeek:\(listId)")
        _ = waitUntilReady(app, scene: "listpeek", markers: ["list.findTable"])
        retryFailedLoad(in: app, until: "list.findTable")
        sleep(12) // pins load after the list's places
        let recenter = app.buttons["map.recenter"]
        if recenter.exists && recenter.isHittable { recenter.tap(); sleep(2) }
        zoomMap(in: app)
        mark("start", "map")
        pause(1.5)
        drag(app, from: (0.5, 0.80), to: (0.5, 0.45)) // pull the list sheet up
        pause(1.5)
        drag(app, from: (0.5, 0.75), to: (0.5, 0.55))
        pause(1.5)
        drag(app, from: (0.5, 0.55), to: (0.5, 0.75)) // back to the top so the preferred tile is on screen
        pause(1.5)
        mark("cut-begin", "map") // place details load after the tap; that stretch is cut in post
        openPlace(in: app, preferred: ["Minetta Tavern", "COTE Flatiron", "Genki Omakase"])
        waitForImages(app)
        drag(app, from: (0.5, 0.715), to: (0.5, 0.25)) // show the place photos
        waitForImages(app)
        mark("cut-end", "map")
        pause(3.5)
        finish("map")
    }

    /// Explore -> featured "Find a table" -> search -> scroll the availability results.
    func testPreviewFindTable() throws {
        let app = launch(scene: "explore")
        _ = waitUntilReady(app, scene: "explore", markers: ["explore.featured"])
        let button = app.descendants(matching: .any).matching(identifier: "explore.featured.findTable").firstMatch
        let listButton = app.buttons["list.findTable"]
        XCTAssertTrue(button.waitForExistence(timeout: 20) || listButton.exists)
        sleep(3)
        mark("start", "findtable")
        pause(2.5)
        mark("cut-begin", "findtable") // the list opens with skeleton tiles; cut until its photos are in
        if button.exists { button.tap() } else { listButton.tap() }
        let search = app.buttons["list.findTable.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 40))
        waitForImages(app)
        mark("cut-end", "findtable")
        pause(2.5)
        mark("search", "findtable")
        mark("cut-begin", "findtable") // results stream in with partial tiles; cut until every tile has its photo
        search.tap()
        waitForResults(app)
        warmResults(app)
        mark("cut-end", "findtable")
        mark("results", "findtable")
        pause(2.5)
        for _ in 0..<3 {
            drag(app, from: (0.5, 0.78), to: (0.5, 0.52))
            pause(2)
        }
        pause(1.5)
        finish("findtable")
    }

    /// Tonight -> picks -> tap a pick so its place peek opens.
    func testPreviewTonight() throws {
        let app = launch(scene: "tonight")
        _ = waitUntilReady(app, scene: "tonight", markers: [])
        let pick = app.buttons.matching(identifier: "tonight.pick").firstMatch
        XCTAssertTrue(pick.waitForExistence(timeout: 60))
        waitForImages(app)
        mark("start", "tonight")
        pause(3.5)
        mark("cut-begin", "tonight") // place details load after the tap; that stretch is cut in post
        openPick(in: app)
        waitForImages(app)
        mark("cut-end", "tonight")
        pause(4)
        drag(app, from: (0.5, 0.715), to: (0.5, 0.35))
        waitForImages(app)
        pause(4)
        finish("tonight")
    }

    // MARK: - Marks and pacing

    /// Prints a marker line the workflow converts into trim points (epoch seconds with decimals).
    private func mark(_ kind: String, _ name: String) {
        print(String(format: "PREVIEW_MARK %@ %@ %.3f", kind, name, Date().timeIntervalSince1970))
    }

    /// Prints the end marker and holds one second so the recording keeps the final state.
    private func finish(_ name: String) {
        mark("end", name)
        sleep(1)
    }

    /// Waits a fixed number of seconds so each state stays on screen.
    private func pause(_ seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }

    /// Drags between two normalized screen points at a slow, deliberate speed.
    private func drag(_ app: XCUIApplication, from: (CGFloat, CGFloat), to: (CGFloat, CGFloat)) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: from.0, dy: from.1))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: to.0, dy: to.1))
        start.press(forDuration: 0.1, thenDragTo: end, withVelocity: XCUIGestureVelocity(300), thenHoldForDuration: 0.3)
    }

    // MARK: - Launch and readiness

    /// Launches the app in screenshot mode, opening `scene` with the demo credentials from the environment.
    private func launch(scene: String) -> XCUIApplication {
        let env = ProcessInfo.processInfo.environment
        let app = XCUIApplication()
        app.launchArguments += ["-MesaScreenshotMode", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment["MESA_SCREENSHOT_SCENE"] = scene
        app.launchEnvironment["MESA_DEMO_EMAIL"] = env["MESA_DEMO_EMAIL"] ?? ""
        app.launchEnvironment["MESA_DEMO_PASSWORD"] = env["MESA_DEMO_PASSWORD"] ?? ""
        app.launch()
        return app
    }

    /// Reads the app's hidden readiness value ("scene=..;shimmer=..;pfp=..;note=..").
    private func readiness(in app: XCUIApplication) -> String? {
        let probe = app.descendants(matching: .any).matching(identifier: "screenshot.ready").firstMatch
        return probe.exists ? probe.value as? String : nil
    }

    /// Waits until the scene is opened, its content visible, shimmer gone and the profile photo loaded, then settles.
    private func waitUntilReady(_ app: XCUIApplication, scene: String, markers: [String]) -> String {
        let deadline = Date().addingTimeInterval(150)
        var last = "no readiness probe"
        var idlePolls = 0
        while Date() < deadline {
            if let value = readiness(in: app) {
                last = value
                let ready = value.contains("scene=\(scene)") && value.contains("shimmer=0") && value.contains("images=1") && value.contains("pfp=1")
                    && hasContent(markers, in: app) && !isLoading(app)
                idlePolls = ready ? idlePolls + 1 : 0
                if idlePolls >= 3 { break }
            }
            sleep(2)
        }
        sleep(4)
        return last
    }

    /// Waits until the app reports every visible image loaded (images=1) and no loading text shows, for three polls in a row.
    private func waitForImages(_ app: XCUIApplication, timeout: TimeInterval = 90) {
        let deadline = Date().addingTimeInterval(timeout)
        var stable = 0
        while Date() < deadline {
            let ok = (readiness(in: app) ?? "").contains("images=1") && !isLoading(app)
            stable = ok ? stable + 1 : 0
            if stable >= 3 { return }
            sleep(1)
        }
    }

    /// Scrolls the results down and back up so every row's photo is in the image cache, then waits for images.
    private func warmResults(_ app: XCUIApplication) {
        for _ in 0..<4 {
            drag(app, from: (0.5, 0.78), to: (0.5, 0.40))
            waitForImages(app, timeout: 30)
        }
        for _ in 0..<4 {
            drag(app, from: (0.5, 0.40), to: (0.5, 0.78))
        }
        waitForImages(app, timeout: 30)
    }

    /// True when one of the marker identifiers or labels exists (always true when there are none).
    private func hasContent(_ markers: [String], in app: XCUIApplication) -> Bool {
        if markers.isEmpty { return true }
        return markers.contains { marker in
            app.descendants(matching: .any).matching(identifier: marker).firstMatch.exists
                || app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", marker)).firstMatch.exists
        }
    }

    /// True while any visible text starts with "Loading" or "Searching".
    private func isLoading(_ app: XCUIApplication) -> Bool {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH[c] 'Loading' OR label BEGINSWITH[c] 'Checking' OR label BEGINSWITH[c] 'Searching'")).count > 0
    }

    // MARK: - Scene helpers

    /// Double-taps the map above the sheet twice so individual Manhattan pins show instead of wide clusters.
    private func zoomMap(in app: XCUIApplication) {
        let spot = app.coordinate(withNormalizedOffset: CGVector(dx: 0.38, dy: 0.22))
        spot.doubleTap()
        sleep(3)
        spot.doubleTap()
        sleep(8)
    }

    /// Waits for the search to finish: the status line reads "Checked N places ..." (no "of") and nothing says Loading.
    private func waitForResults(_ app: XCUIApplication, timeout: TimeInterval = 150) {
        sleep(2)
        let done = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Checked' AND NOT label CONTAINS ' of '"))
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if done.count > 0 && !isLoading(app) { break }
            sleep(2)
        }
        sleep(3)
    }

    /// Taps "Try again" until `identifier` appears (or ~60 s pass) when a list or place failed to load.
    private func retryFailedLoad(in app: XCUIApplication, until identifier: String) {
        for _ in 0..<12 {
            if app.descendants(matching: .any).matching(identifier: identifier).firstMatch.exists { return }
            let retry = app.buttons["Try again"]
            if retry.exists && retry.isHittable { retry.tap() }
            sleep(5)
        }
    }

    /// Taps the first Tonight pick whose place details load; backs out and tries the next pick if they stay on "Loading".
    private func openPick(in app: XCUIApplication) {
        let picks = app.buttons.matching(identifier: "tonight.pick")
        for index in 0..<min(picks.count, 3) {
            let pick = picks.element(boundBy: index)
            guard pick.exists && pick.isHittable else { continue }
            pick.tap()
            let loading = app.staticTexts["Loading Place Details..."]
            let deadline = Date().addingTimeInterval(12)
            while loading.exists && Date() < deadline { sleep(1) }
            if !loading.exists { return }
            let back = app.navigationBars.buttons.firstMatch
            if back.exists { back.tap(); sleep(2) }
        }
    }

    /// Taps the first visible tile whose title starts with one of `preferred` (in order); does nothing when none is on screen.
    private func openPlace(in app: XCUIApplication, preferred: [String]) {
        for name in preferred {
            let titles = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", name))
            for index in 0..<titles.count {
                let title = titles.element(boundBy: index)
                if title.isHittable { title.tap(); return }
            }
        }
    }
}
