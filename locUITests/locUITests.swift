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
/// Each scene relaunches the app in DEBUG screenshot mode; the app signs in the demo
/// account (env from CI secrets) and opens the scene itself. Screenshots are kept as
/// XCTAttachments named "<n>_<scene>" and exported from the .xcresult by the workflow.
final class ScreenshotTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    private func scenes() -> [(String, String)] {
        let env = ProcessInfo.processInfo.environment
        func id(_ key: String) -> String { env[key] ?? "" }
        var list: [(String, String)] = [("01_tonight", "tonight")]
        if !id("SCREENSHOT_PICK_ID").isEmpty { list.append(("02_pick", "pick:\(id("SCREENSHOT_PICK_ID"))")) }
        list.append(("03_map_lists", "map"))
        if !id("SCREENSHOT_LIST_ID").isEmpty { list.append(("04_list", "list:\(id("SCREENSHOT_LIST_ID"))")) }
        if !id("SCREENSHOT_PLACE_ID").isEmpty { list.append(("05_place", "place:\(id("SCREENSHOT_PLACE_ID"))")) }
        list.append(("06_trips", "trips"))
        list.append(("07_profile", "profile"))
        return list
    }

    func testCaptureAppStoreScreenshots() throws {
        let env = ProcessInfo.processInfo.environment
        addUIInterruptionMonitor(withDescription: "System alerts") { alert in
            for label in ["Allow While Using App", "Allow", "OK", "Don’t Allow", "Not Now"] {
                if alert.buttons[label].exists { alert.buttons[label].tap(); return true }
            }
            return false
        }
        for (name, scene) in scenes() {
            let app = XCUIApplication()
            app.launchArguments += ["-MesaScreenshotMode"]
            app.launchEnvironment["MESA_SCREENSHOT_SCENE"] = scene
            app.launchEnvironment["MESA_DEMO_EMAIL"] = env["MESA_DEMO_EMAIL"] ?? ""
            app.launchEnvironment["MESA_DEMO_PASSWORD"] = env["MESA_DEMO_PASSWORD"] ?? ""
            app.launch()
            // Let sign-in, data load, sheet presentation and image loading settle.
            sleep(UInt32(env["SCREENSHOT_SETTLE_SECONDS"] ?? "14") ?? 14)
            let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            shot.name = name
            shot.lifetime = .keepAlways
            add(shot)
            app.terminate()
        }
    }
}
