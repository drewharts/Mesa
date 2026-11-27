# Skill testing by replay (PLAN ONLY - not implemented)

## Goal
Know whether a change to a skill (or to AGENTS.md) actually makes agents fail less, by replaying real past requests against old vs new instructions and scoring with the hard CI checks - not by vibes.

## Corpus (seed from git history)
Each case = a prompt that reproduces the original request, the repo state just before the fix (`<parent of fix>`), and a machine-checkable expected outcome.

| # | Past failure | Fix commit | Prompt sketch | Expected check |
|---|---|---|---|---|
| 1 | Duplicate `ShimmerModifier` | 9090845 | "Add shimmer skeleton placeholders to Explore cards" | `ci/check_duplicate_types.py` passes; no new `ShimmerModifier` |
| 2 | Methods inserted in wrong type (`TripTimeline` enum) | 32dd3a6 | "Add map-exit handling to TripsListViewModel" | build/unit tests compile; methods are inside the class (grep in checker) |
| 3 | Missing stored-property type | ddc2d58 | "Add allowsGrid option to PlacePhotoCollage" | build passes (xcodebuild in checks.yml) |
| 4 | `nonisolated` missing in MainActor VM | c3d4841 | "Extract GPS from photo EXIF off the main thread" | archive/build passes; function is `nonisolated` |
| 5 | Default-param method used as function reference | 6622765 | "Add makeList parsing to ExploreListsService" | build passes |
| 6 | Brace mismatch | 4b5b98c | "Refactor ListPlacesScrollView overlay" | lint/build passes |
| 7 | Body type-check blowup | 0065a6e, b22f1b7 | "Restore map camera when leaving a trip" | build passes; no new `.onChange` chain growth |
| 8 | Version train closed | 17bca25, b9be475 | "Prepare the next TestFlight build after 5.06 approval" | `version` job passes |
| 9 | File outside synced folder not compiled | 0f8babf, ac424a0 | "Add a helper for map camera settling" | file lives in a synced folder; build passes |
| 10 | Vague bug -> wrong UI | (none yet) | "map didn't reset after leaving a trip" | agent opens FEATURE_MAP.md Trips entry; touches the listed files |

Store each as `docs/skills/replay/<n>.md` (prompt + base SHA + expected check) when implemented.

## Procedure
1. For each case: create scratch branch `replay/<n>-<skill-version>` from the base SHA (never from `main`, never pushed to `testflight`).
2. Run an agent with the **old** skill set and one with the **new** skill set on the same prompt (same model, same budget). Fresh context each.
3. Push scratch branches; checks.yml scores them: lint, duplicate types, version, unit tests, (later) ui-smoke. Score = pass/fail per check plus diff size and number of agent turns.
4. Compare: a skill change ships only if it fixes >= 1 failing case and regresses none. Repeat each case 3x to smooth variance.
5. Delete scratch branches after scoring.

## Cadence
Run the corpus whenever a skill/AGENTS.md changes materially, and monthly. Add a case for every new agent failure that reaches CI (the failure's fix commit is the seed).

## Not yet built
Harness script (`ci/replay.py`), corpus files, scoring table, cost budget. Open item in `docs/AGENT_NOTES.md`.
