# Mesa agent notes (running log)

Newest entries first. Skimmable on purpose: decisions, how to use, open items.

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

(Appended by the CI-checks work on its branch: checks.yml, .swiftlint.yml, ci/*.py, ci/last_released_version.txt, ci/quarantined_tests.txt, locUITests smoke tests with `A11yID`.)
