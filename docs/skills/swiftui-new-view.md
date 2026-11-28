# Skill: add a SwiftUI view / modifier without duplicating types

## When to use
Creating any new `struct`, `class`, `enum`, `ViewModifier`, or `View` extension.

## Why
Swift modules have one global type namespace. A duplicate name is a hard build error (`invalid redeclaration`) that is only visible in CI. It already happened: commit 9090845 ("drop duplicate declaration that broke the build") - a second `ShimmerModifier` was added when `loc/Views/Components/ShimmerView.swift` already defines `ShimmerModifier` and `.shimmering(active:)`.

## Steps
1. Search first. For every new type name `Foo`:
   `grep -rnE "(struct|class|enum|actor|protocol|typealias) Foo\b" loc ShareExtension MesaShare locTests locUITests`
   Also search by purpose: `grep -rni "shimmer\|skeleton" loc/Views` before writing a loading placeholder.
2. Prefer reuse. Existing building blocks: `ShimmerModifier` / `.shimmering()` and `SkeletonStyle.base` (loc/Views/Components), `loc/Views/SharedComponents/` (covers, pills, collages), `loc/Views/ReusableViews/`.
3. Name new types with the feature prefix: `ExploreCitySkeletonCard`, `TripMapPlacePin`, `ProfileQuickActionsRow`. Generic names (`Card`, `Row`, `Header`, `Skeleton`) collide.
4. One type per file, file named after the type, placed in the feature's folder (`loc/Views/<Feature>/Foo.swift`). The app target uses synced folders, so files on disk are picked up automatically; a file left outside a synced group is silently not compiled (see commits 0f8babf, ac424a0 about moving files into synced folders).
5. Give interactive elements an accessibility identifier per the scheme in FEATURE_MAP.md and add it to the map.
6. Run `python3 ci/check_duplicate_types.py` (written by the CI checks work; see docs/AGENT_NOTES.md "CI hard checks") and fix anything it prints.

## Checks
- [ ] grep shows exactly one declaration of each new type.
- [ ] Every stored property has an explicit type (`let allowsGrid: Bool`, see commit ddc2d58 where the type was dropped).
- [ ] Braces balance (see wrong-type-placement.md).

## Examples
- Good: skeleton cards named `ExploreListSkeletonCard`, using `.shimmering()` and `SkeletonStyle.base`.
- Bad: `struct ShimmerModifier: ViewModifier` in a second file.
