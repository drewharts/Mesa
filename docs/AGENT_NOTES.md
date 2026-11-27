# Mesa agent notes (running log)

## CI hard checks (2026-11-27)

Workflow: `.github/workflows/checks.yml` (push to `feature/**`, `workflow_dispatch`, `workflow_call` with input
`include_ui_smoke`). Goal: mechanically catch recurring coding-agent failures. Everything is compiled/tested only
in GitHub Actions (no Xcode locally) — **push and read the run before declaring work done.**

| Job | Runner | Catches | Failure |
|---|---|---|---|
| `lint` | macos-26 | banned patterns + correctness rules (`.swiftlint.yml`), only NEW violations vs `ci/swiftlint-baseline.json` | blocking |
| `structure` | ubuntu | duplicate top-level `struct/class/enum/actor/protocol/typealias` per module (`ci/check_duplicate_types.py`, honours pbxproj target membership) | blocking |
| `version` | ubuntu | `MARKETING_VERSION` of `loc` must be > latest Apple-approved version (`ci/check_marketing_version.py`) | blocking |
| `unit-tests` | macos-26 | `xcodebuild test -only-testing:locTests` — compile errors (isolation, wrong-type methods, missing annotations) + test failures; `.xcresult` artifact | blocking |
| `ui-smoke` | macos-26 | XCUITest launch + sign-in screen screenshot (`smoke-screenshots` artifact) | `continue-on-error`, never gates TestFlight |

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
`TEST_ACCOUNT_EMAIL`/`TEST_ACCOUNT_PASSWORD`, fed from secret `TEST_ACCOUNT` = `email:password`, and the sign-in screen
has `auth.email`/`auth.password`/`auth.signIn` — the shipping app only has Apple/Google sign-in, so these skip; no auth
bypass exists or should be added). Identifiers live in `locUITests/A11yID.swift`, naming `area.element`.
Screenshots: `XCTAttachment` with `.keepAlways`, exported with `xcresulttool export attachments`.

### Not done / rejected
- Enum-instance-method heuristic (failure #3): skipped — a regex cannot reliably tell a legitimate static helper
  enum from instance methods on the wrong type; the compiler catches it once `unit-tests` builds.
- Type-annotation failures (#4) and isolation errors (#2) are caught by the compiler in `unit-tests`; the lint rules above
  only block the escape hatches.
