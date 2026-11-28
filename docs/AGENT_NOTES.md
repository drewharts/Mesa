# Mesa agent notes (running log)

Newest entries first. Skimmable on purpose: decisions, how to use, open items.

## 2026-11-27 - App Store preview videos (feature/appstore-shots)

`.github/workflows/previews.yml` (iPhone 17 Pro Max only) records `locUITests/PreviewTests` (`testPreviewMap`, `testPreviewFindTable`,
`testPreviewTonight`) with `simctl io recordVideo`. Trigger: push to `feature/appstore-shots` whose head commit message contains the tag
"previews" in square brackets (screenshots.yml skips those pushes), or workflow_dispatch. Same secrets as screenshots (`MESA_DEMO_EMAIL`,
`MESA_DEMO_PASSWORD`, `GMS_API_KEY`). Artifact `previews-raw`: `<name>.mov`, `<name>.marks.txt` (`record_start` epoch plus
`PREVIEW_MARK start|end|...` epochs; trim window = mark minus record_start, accurate to about 1-2 s), xcodebuild logs. Each recording
also holds the app launch/sign-in dead time, so always trim. Find-a-table results stream in for ~18 s (marks `search` and `results`
bracket it); speed that stretch up in post. Privacy: place "saved by" avatars are now greyed in screenshot mode
(`PlaceDetailTabsView.SavedByIndicator`). Added `tonight.pick` accessibility id on `TonightPickCard`.

## 2026-11-27 - App Store screenshot pipeline (feature/appstore-shots)

`.github/workflows/screenshots.yml` builds Debug for two simulators (iPhone 17 Pro Max "6.9", iPhone 11 Pro Max "6.5"; the 11 Pro Max
renders 1242x2688, `ci/screenshots/frame.py` resizes to ASC sizes), runs `locUITests/ScreenshotTests`, and uploads artifacts
`screenshots-<size>` (PNG + `diag_*.txt`) and `shots-xcresult-<size>`. Triggers: push to `feature/appstore-shots` or manual dispatch.
Secrets: `MESA_DEMO_EMAIL`, `MESA_DEMO_PASSWORD` (forwarded as `TEST_RUNNER_MESA_DEMO_*`), `GMS_API_KEY`. Read-only: it signs in and views.
App side is `#if DEBUG` + launch arg `-MesaScreenshotMode`: `loc/Services/Debug/ScreenshotMode.swift` (read-only sign-in, scene opener via
AppTabRouter/PresentationService/deep link, profile-photo load with retries), `ScreenshotPrivacy` (neutral names, no other people's faces),
`ScreenshotReadiness` + `ScreenshotReadinessProbe` (hidden `screenshot.ready` element: shimmer count, pfp loaded). It does NOT use the
UITEST_* login hook because that path (handleUserMigration) can write the users row. Download: `gh run download <id> -n screenshots-6.9`.
Known gaps: some Explore city covers have no photos (gradient fallback; `PlacePhotoCollage` shimmers forever when no candidate loads -
product bug, only masked in screenshot mode); Tonight (07) shows placeholder thumbnails for places without photos.

## 2026-11-27 - TestFlight release gate

`.github/workflows/testflight.yml` now has a `checks` job (`uses: ./.github/workflows/checks.yml`, `secrets: inherit`,
`include_ui_smoke: false`) and `upload` has `needs: checks`. **Upload runs only if `lint`, `structure`, `version` and
`unit-tests` all pass.** `ui-smoke` is skipped on testflight runs (and is `continue-on-error` anyway); it still runs on
`feature/**` pushes. `checks.yml` no longer triggers on pushes to `testflight` (it would run twice); it triggers on
`feature/**` pushes, `workflow_dispatch` and `workflow_call`. A failing gate shows as a red `checks / <job>` in the
TestFlight run; fix the cause (see "CI hard checks"), do not remove the `needs`. Build number is still 1000 + run number
(`vars.BUILD_NUMBER_OFFSET`), so a gated-out run burns a number. Open: promote ui-smoke to a gate once stable;
`TEST_ACCOUNT` secret for signed-in flows; skill replay testing.

## 2026-11-26/27 (ET) - Phase 1: building trust in coding agents

Source: Lauren Tan's Cursor talk on building trust in coding agents. Five principles and how each maps to Mesa:

| Principle | Mesa implementation |
|---|---|
| Agents verify by **running the app like a user** | XCUITest smoke flows in `locUITests/` run on a simulator in CI; screenshots attached and downloadable. Playbook: `docs/skills/verify-mesa.md`. |
| A **feature map** turns vague bug reports into concrete UI | `FEATURE_MAP.md`: every user-facing feature -> tap path -> files -> view models -> accessibility IDs -> backend endpoints/tables -> caveats. |
| **Hard CI checks** beat soft rules | `.github/workflows/checks.yml`: lint (`.swiftlint.yml`), duplicate-type check, version check, unit tests; TestFlight gated on them. See "CI hard checks" below. |
| **Skills** for recurring failures, tested by replaying past requests | `docs/skills/*.md` (one per real past failure class) + a replay-testing plan (not built). |
| **Strict conventions** so the shortest path is the correct one | `AGENTS.md` (short rules), accessibility-ID naming scheme, one-type-per-file/one-folder-per-feature, `CLAUDE.md` pointer block. |

### What was set up
- `FEATURE_MAP.md` (repo root) with how-to-use, index, naming scheme, full ID table, gaps.
- Accessibility identifiers: **89 identifiers** added across the app in the `area.element[.qualifier]` scheme (static strings only). Every ID is recorded in FEATURE_MAP.md (ID -> file:line -> element). Pre-assigned names that do not exist in the UI (e.g. `auth.signIn`, `auth.email`, `auth.password`: there is no email/password login, only Apple and Google) are listed as "not applicable" in the map.
- `AGENTS.md` (conventions), `CLAUDE.md` start-here block + corrected xcodebuild statement (applies to Drew's machine; agents use CI) and stale `Loc.xcodeproj`/path fixes.
- `docs/skills/`: verify-mesa, swiftui-new-view, main-actor, wrong-type-placement, type-annotations, version-bump, replay-testing (plan), README index.
- CI hard checks are being added in parallel on another branch. See 'CI hard checks' section below.

### Decisions
- **XCUITest over Maestro for now.** It is native, needs no extra tooling on the macOS runner, and can use the same accessibility IDs. Maestro remains an optional future alternative.
- **UI smoke is non-blocking** at first (simulator flakiness); unit tests and the static checks are the gate. Promote flows to a release gate once stable.
- **No test account and no auth bypass** until Drew approves. Signed-in flows are skipped until a `TEST_ACCOUNT` secret exists. We will not add a debug/release backdoor for auth.
- **Lint starts from a baseline** so existing violations don't block; only new violations fail.
- **Version check has a fallback file** (`ci/last_released_version.txt`) for when App Store Connect is unreachable.
- Doc-only + one-line `.accessibilityIdentifier` edits only on the Swift side: nothing compiled here (no Xcode), so every edit was the lowest-risk kind; CI is the compiler. The unsure placements are listed in `/workspace/cc-logs/guardrails-docs-report.md`.

### How to use
1. Vague bug report -> `FEATURE_MAP.md` index -> feature -> files/IDs.
2. Before coding: `AGENTS.md` and the matching skill in `docs/skills/`.
3. Verify via a feature-branch push and `docs/skills/verify-mesa.md`.
4. When you add UI: add IDs, update FEATURE_MAP.md. When a failure repeats: write/extend a skill and add a replay case.

### Open items
- [ ] `TEST_ACCOUNT` secret (needs Drew's approval) to enable signed-in UI flows.
- [ ] Promote stable UI flows to a release gate.
- [ ] Replay harness for skills (plan in `docs/skills/replay-testing.md`).
- [ ] More accessibility IDs: trip map/itinerary, followers/following rows, list selection sheets, shared `FilterChip`, system alert buttons.
- [ ] Verify the accessibility-ID edits compile (first CI run) and that duplicate IDs (e.g. `onboarding.continue`, `explore.shortcut`, `profile.lists.add` in two presentations) behave in tests.
- [ ] Delete account is not implemented server-side (see FEATURE_MAP.md "Settings") - App Store risk; needs a decision.

## CI hard checks

Workflow: `.github/workflows/checks.yml` (push to `feature/**`, `workflow_dispatch`, `workflow_call` with input
`include_ui_smoke`). Goal: mechanically catch recurring coding-agent failures. Everything is compiled/tested only
in GitHub Actions (no Xcode locally) — **push and read the run before declaring work done.**

| Job | Runner | Catches | Failure |
|---|---|---|---|
| `lint` | macos-26 | banned patterns + correctness rules (`.swiftlint.yml`), only NEW violations vs `ci/swiftlint-baseline.json` | blocking |
| `structure` | ubuntu | duplicate top-level `struct/class/enum/actor/protocol/typealias` per module (`ci/check_duplicate_types.py`, honours pbxproj target membership) | blocking |
| `version` | ubuntu | `MARKETING_VERSION` of `loc` must be > latest Apple-approved version (`ci/check_marketing_version.py`) | blocking |
| `unit-tests` | macos-26 | `xcodebuild test -only-testing:locTests` — compile errors (isolation, wrong-type methods, missing annotations) + test failures; `.xcresult` artifact | blocking |
| `ui-smoke` | macos-26 | XCUITest launch + sign-in screen screenshot; artifacts `smoke-screenshots` (PNGs) and `ui-smoke-xcresult` | `continue-on-error`, never gates TestFlight |

**Gating:** TestFlight uploads require lint + structure + version + unit-tests (see 2026-11-27 entry). Other artifacts: `unit-tests-xcresult`, `swiftlint-baseline-fresh`.

### Lint rules (all documented in `.swiftlint.yml`)
Opt-in only (`only_rules`), no style rules. Built-ins: duplicate_conditions, duplicate_enum_cases, force_try,
force_cast, unowned_variable_capture, class_delegate_protocol, legacy_hashing, empty_xctest_method,
private_unit_test (private tests are never run), unused_capture_list, etc. Custom regex rules: `nonisolated(unsafe)`,
`@preconcurrency import`, `MainActor.assumeIsolated`, `@unchecked Sendable`, `Task.detached` without a same-line
`// detached: <reason>` comment, `fatalError("TODO` / `TODO: implement` stubs. Existing hits are grandfathered in
the baseline; **new code must not add any** — fix the code, don't regenerate the baseline.
Regenerate (only when deliberately accepting debt): download the `swiftlint-baseline-fresh` artifact of a lint run
and commit it as `ci/swiftlint-baseline.json`. SwiftLint is pinned (0.65.1) in checks.yml; the baseline is version-sensitive.

### Duplicate types
`python3 ci/check_duplicate_types.py` runs anywhere (pure Python). Files that exist on disk but are not part of
the target in `project.pbxproj` are ignored (e.g. `loc/Utilities/PlaceTypeTranslator.swift` duplicates
`loc/Extensions/` but is not compiled). `private`/`fileprivate` top-level types are file-scoped and allowed.
**`locUITests` uses explicit file references** (not a synchronized folder): a new UI test file must be added to
`project.pbxproj` by hand (PBXBuildFile + PBXFileReference + group + Sources phase), otherwise it is silently not compiled.

### Marketing version
`ci/check_marketing_version.py` asks App Store Connect (secrets `ASC_KEY_P8_BASE64`, `ASC_KEY_ID`, `ASC_ISSUER_ID`) for the
highest iOS version in an approved-or-later state and fails if `loc`'s MARKETING_VERSION is `<=` it. Apple compares
integer components: 5.07 == 5.7 > 5.06, and 5.1 < 5.07 — after 5.07 use 5.08, never 5.1. Fallback without secrets:
`ci/last_released_version.txt` (refresh with `python3 ci/check_marketing_version.py --write` with ASC env set).
On failure: bump MARKETING_VERSION (loc + MesaShare, Debug+Release) in `loc.xcodeproj/project.pbxproj`.
`ci/asc_submit.py` is the submit flow; it cannot commit, so it does not update the fallback file.

### Unit tests
Quarantine flaky/broken tests in `ci/quarantined_tests.txt` (`locTests/Class[/method]  # reason`), never delete them.
Simulator is chosen dynamically (newest iOS runtime, first iPhone). Secrets.xcconfig is written with dummies for unit tests.

### UI smoke
Tests: `locUITests/MesaSmokeTests.swift` (signed-out sign-in screen), `MesaSignedInFlowTests.swift` (skips unless
`TEST_ACCOUNT_EMAIL`/`TEST_ACCOUNT_PASSWORD` are set). Signed-in login does NOT type into fields (flaky keyboard focus):
CI passes secrets `TEST_ACCOUNT_EMAIL`/`TEST_ACCOUNT_PASSWORD` as `TEST_RUNNER_TEST_ACCOUNT_*` env vars; the test copies them
into `app.launchEnvironment` as `UITEST_EMAIL`/`UITEST_PASSWORD`, and a `#if DEBUG` hook in `LoginView.onAppear` calls
`LoginViewModel.signInFromLaunchEnvironmentForUITests`. Release builds contain none of it; the testflight.yml guard step fails
the archive if `MesaUITestEmailLogin` or `UITEST_PASSWORD` strings appear in the binary. Identifiers live in `locUITests/A11yID.swift`, naming `area.element`.
Screenshots: `XCTAttachment` with `.keepAlways`, exported with `xcresulttool export attachments`.

### Not done / rejected
- Enum-instance-method heuristic (failure #3): skipped — a regex cannot reliably tell a legitimate static helper
  enum from instance methods on the wrong type; the compiler catches it once `unit-tests` builds.
- Type-annotation failures (#4) and isolation errors (#2) are caught by the compiler in `unit-tests`; the lint rules above
  only block the escape hatches.
