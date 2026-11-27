# AGENTS.md - conventions for coding agents on Mesa

Mesa ("Loc") is a social iOS app (SwiftUI + Supabase) for saving, sharing and discovering places. The map is the base layer; Explore and Trips are bottom sheets over it; Profile is a full page. Backend is a separate Python repo (Mesa-backend).

Start here: [FEATURE_MAP.md](FEATURE_MAP.md) (what users see -> files -> accessibility IDs) - [docs/AGENT_NOTES.md](docs/AGENT_NOTES.md) (decisions, open items) - [docs/skills/](docs/skills/README.md) (playbooks) - [CLAUDE.md](CLAUDE.md) / [ARCHITECTURE.md](ARCHITECTURE.md) (MVVM rules).

## Where things live
- `loc/Views/<Feature>/` SwiftUI views (Explore, Trips, ListViews, MyProfileViews (profile), PlaceDetailViews, Map, Search, Onboarding, ...); shared bits in `Views/SharedComponents/`, `Views/Components/`, `Views/ReusableViews/`.
- `loc/ViewModels/` (feature subfolders like `Trips/`, `Explore/`, `Lists/`), `loc/Services/` (Supabase + backend + caches), `loc/Models/`, `loc/Managers/`, `loc/Utilities/`.
- `ShareExtension/`, `MesaShare/` share extension; `locTests/` unit tests; `locUITests/` UI smoke tests; `ci/` scripts; `.github/workflows/` CI.
- The layout is not perfectly consistent (some feature code sits at the top level of `Views/` or `ViewModels/`). **New features: one folder per feature**, with its views, view models and services colocated (`Views/Foo/`, `ViewModels/Foo/`), and a FEATURE_MAP.md entry.

## Rules
1. Read FEATURE_MAP.md before changing UI. When you add or change UI, update the map and add accessibility IDs (`area.element[.qualifier]`, lowercase-first camelCase, **static** strings, no ids/indices - see the scheme in FEATURE_MAP.md).
2. Never define a type that already exists. Before adding `struct|class|enum|actor|protocol Name`, grep the repo for it (`ShimmerModifier` / `.shimmering()` already exist). See docs/skills/swiftui-new-view.md. One type per file, file named after the type.
3. UI state and ViewModels are `@MainActor` (`@MainActor class X: ObservableObject`). Pure off-main helpers are `nonisolated`. See docs/skills/main-actor.md.
4. Put methods inside the type they belong to. Files often hold a class **and** an enum; check brace scope before inserting (docs/skills/wrong-type-placement.md). Prefer a named `extension`.
5. Add explicit type annotations on complex closures, empty literals and stored properties; split large `body`s (docs/skills/type-annotations.md).
6. MVVM is strict: no logic or network calls in Views; one-sentence `///` comment above every function (CLAUDE.md).
7. Versions: after Apple approves a version, bump `MARKETING_VERSION` (app + MesaShare targets, 4 lines) in `loc.xcodeproj/project.pbxproj` or the TestFlight upload fails. CI `version` job checks against `ci/last_released_version.txt` / App Store Connect. See docs/skills/version-bump.md.
8. There is **no Xcode on the agent box; CI is the compiler.** Run cheap local checks (`python3 ci/check_duplicate_types.py`, grep, brace review), push a feature branch, read the `checks.yml` result. It runs lint, duplicate-type check, version check and unit tests; TestFlight upload is gated on them. Verify behavior with docs/skills/verify-mesa.md.
9. Never commit secrets (`Secrets.xcconfig` is gitignored; API keys come from CI secrets). Never print them.
10. Never push to `main`. Pushing to `testflight` triggers a TestFlight build (build number = 1000 + CI run number); only Drew decides that. Don't commit untested UI changes on Drew's behalf (CLAUDE.md git rules) - commit locally on a feature branch and say what is unverified.
11. Backend (Mesa-backend) is a separate repo; treat it as read-only unless asked. Look up endpoint paths there.

## Definition of done
Builds in CI, checks green, FEATURE_MAP.md and accessibility IDs updated, a new/updated skill if you hit a recurring failure, and a short note in docs/AGENT_NOTES.md for decisions Drew should know about.
