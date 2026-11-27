# Skill: version bump / TestFlight / App Store train

## When to use
Anything involving `MARKETING_VERSION`, TestFlight uploads, App Store submission, release notes, or a CI failure from the `version` check or from the TestFlight "upload" step.

## The rule
Apple closes a version "train" once that version is approved/released. After **Apple approves version X**, every later build must have `MARKETING_VERSION` > X, otherwise the TestFlight/App Store upload is rejected (error that the train is closed / version must be higher). History: 17bca25 "Bump marketing version to 5.07 (5.06 approved; TestFlight train closed)"; also b9be475, fa35c0c.
Mesa versions are decimal strings in the 5.xx series (`5.07`, next `5.08`).

## Where it lives
`loc.xcodeproj/project.pbxproj` has `MARKETING_VERSION = 5.07;` in **four** places: the `loc` app target (Debug + Release, ~lines 650/691) and the `MesaShare` extension (Debug + Release, ~lines 792/829). Test targets are `1.0` - leave those alone. App and extension must match. Change all four with one command, e.g.
`sed -i 's/MARKETING_VERSION = 5.07;/MARKETING_VERSION = 5.08;/' loc.xcodeproj/project.pbxproj`, then `grep -n MARKETING_VERSION loc.xcodeproj/project.pbxproj` to confirm only `1.0` and the new version remain.

## Build numbers
- `testflight` branch push -> `.github/workflows/testflight.yml` -> build number = `1000 + run_number` (`vars.BUILD_NUMBER_OFFSET` can override).
- `appstore.yml` (manual dispatch from main) -> build number `2000 + run_number`; it reads the version from the Release build settings and runs `ci/asc_submit.py <version> <build> release_notes_<version>.txt`.

## CI checks
- `checks.yml` `version` job compares `MARKETING_VERSION` to `ci/last_released_version.txt` (the last version Apple approved; falls back to this file when App Store Connect is unavailable) and fails if it is not greater.
- After Apple approves a version: update `ci/last_released_version.txt` to it **and** bump `MARKETING_VERSION` to the next version in the same commit.

## Release notes
`ci/release_notes_<version>.txt` (see `ci/release_notes_5.04.txt`): plain bullet lines starting with `- `, user-facing, past tense, **no emoji** (App Store Connect rejects/mangles them). Needed only for versions submitted to App Store review.

## Steps
1. Confirm what Apple approved (ask Drew if unsure; do not guess).
2. Bump all four `MARKETING_VERSION`s; update `ci/last_released_version.txt` if a release was approved.
3. If shipping to review: add `ci/release_notes_<new>.txt`.
4. Push to a feature branch; wait for checks.yml `version` job; only then merge to `testflight` (Drew decides; never push `main`).

## Checks
- [ ] `grep MARKETING_VERSION` shows `1.0` x4 and the new version x4.
- [ ] New version > `ci/last_released_version.txt`.
- [ ] No emoji in release notes: `grep -nP '[^\x00-\x7F]' ci/release_notes_<v>.txt` prints nothing.
