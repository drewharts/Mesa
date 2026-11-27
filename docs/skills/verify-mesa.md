# Skill: verify a Mesa change like a user

## When to use
After any change that affects what a user sees or does (UI, navigation, map behavior, import flows), and before telling Drew it works. Unit tests alone do not prove a flow works.

## Background
- The agent box has no Xcode or simulator. Verification happens in GitHub Actions on a macOS runner: `.github/workflows/checks.yml` runs lint, duplicate-type check, version check, unit tests (`locTests`), and a **ui-smoke** job (XCUITest in `locUITests/`, using `A11yID` constants for accessibility identifiers) on an iOS simulator. UI smoke is non-blocking for now; unit tests gate TestFlight.
- Signed-in flows (map, Explore, Trips, Profile) need an account. They are **skipped until a `TEST_ACCOUNT` secret exists**. Drew has not approved creating a test account, and there is no auth bypass in release builds. Do not add one. Today the smoke tests cover launch and the signed-out screens (login/onboarding entry).
- Never run `xcodebuild` expecting it to work locally. (CLAUDE.md's "don't run xcodebuild" applies to Drew's machine; for agents CI is the way.)

## Steps
1. Locate the feature: open `FEATURE_MAP.md`, find the feature, note its files and accessibility IDs.
2. Run cheap local checks: `python3 ci/check_duplicate_types.py`, `git diff --stat`, re-read braces around every edit (see `wrong-type-placement.md`).
3. Commit to a feature branch and push it (never `main`; only push when Drew's instructions allow pushing). Pushing to `testflight` triggers a TestFlight upload, so do **not** use it for verification.
4. Find the run: `gh run list --branch <branch> --limit 3`, then `gh run watch <id>`.
5. Download artifacts: `gh run download <id> -n smoke-screenshots -D /tmp/run-<id>/shots` and the xcresult (list artifacts with `gh run view <id>`; exact artifact names are defined in checks.yml, use `gh run download <id> -n <name> -D /tmp/run-<id>/<dir>`).
6. Look at the screenshots with the Read tool (it renders PNGs). Check: right screen, no blank map, no spinner stuck, identifiers present.
7. Read logs: `gh run view <id> --log-failed`; for xcresult details on a Mac `xcrun xcresulttool get test-results summary --path <x>.xcresult`; on Linux grep the uploaded `.log` files for `error:` and `Test Case .* failed`.
8. If a flow is missing, add one (below), push again, repeat.

## Adding a new flow (XCUITest)
- File under `locUITests/`, class `...SmokeTests`. Use constants, never raw strings: `app.buttons[A11yID.Tab.explore]`.
- Launch: `let app = XCUIApplication(); app.launch()`.
- Wait, don't sleep: `XCTAssertTrue(el.waitForExistence(timeout: 10))`.
- Screenshot every step so the reviewer sees it:
  ```swift
  let att = XCTAttachment(screenshot: app.screenshot())
  att.name = "01-login"; att.lifetime = .keepAlways
  add(att)
  ```
- Need a new identifier? Add `.accessibilityIdentifier("area.element")` in the app (scheme in FEATURE_MAP.md), add it to `A11yID`, and add a row to FEATURE_MAP.md.
- If the flow needs sign-in, guard with `try XCTSkipUnless(ProcessInfo.processInfo.environment["TEST_ACCOUNT"] != nil)` so it skips cleanly.

## Mapping a vague bug report to UI (worked example)
Report: "the map didn't reset after leaving a trip".
1. FEATURE_MAP.md -> "Trips" (trip detail, map overlays, exit). Reach: Tab bar -> Trips -> a trip row -> (trip map) -> close / back / switch tab.
2. Files: `loc/Views/Trips/TripMapExitModifier.swift`, `loc/ViewModels/Trips/TripsListViewModel.swift` (`clearTripsRemoved`, `beginTripSession`, `clearTrips`), `MapDisplayCoordinatorViewModel` (`clearTripFromMap`), `loc/Views/Containers/MapContainerView.swift` (`handleTripModeChange`). Git history: commits 3b29a95, b22f1b7, 0065a6e, 32dd3a6.
3. IDs: `tab.trips`, `trips.row`, `trip.close`, `tab.map`.
4. Flow that reproduces it (once signed-in flows are enabled): tap `tab.trips` -> tap first `trips.row` -> screenshot (pins visible) -> tap `trip.close` -> tap `tab.map` -> screenshot (pins gone, camera restored). Compare the two screenshots.
5. Fix, push, read the CI screenshots.

## Checks
- [ ] The screenshot shows the expected UI after the change, not just that CI is green.
- [ ] New UI has accessibility IDs in the scheme and a row in FEATURE_MAP.md.
- [ ] Skipped flows are reported as skipped, not as passed.

## Future
Maestro (YAML flows against a simulator) is a possible alternative to XCUITest; not adopted. See `docs/AGENT_NOTES.md`.
