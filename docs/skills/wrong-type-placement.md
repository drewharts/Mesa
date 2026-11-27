# Skill: don't insert methods into the wrong type

## When to use
Whenever you add a method/property to a file that contains more than one type (class + enum + extension is common in Mesa), or after moving code between files.

## The incident
Commit 32dd3a6 "TripsListViewModel: move map-exit methods into the view model class (were in TripTimeline enum)". `loc/ViewModels/Trips/TripsListViewModel.swift` declares `@MainActor class TripsListViewModel` *and, lower in the same file*, `enum TripTimeline`. An earlier change appended three methods (`clearTripsRemoved`, `beginTripSession`, `clearTrips`) at the end of the file, i.e. inside `TripTimeline`. Callers used `viewModel.clearTrips(...)`, so the build failed (`value of type 'TripsListViewModel' has no member 'clearTrips'`) - and since the enum is not `@MainActor`, the methods also touched main-actor types from a nonisolated context. The fix moved the block above the class's closing brace. Inspect: `git show 32dd3a6`.

## Steps
1. List the types in the file before inserting: `grep -nE "^(@MainActor )?(final )?(struct|class|enum|extension|actor|protocol) " path.swift`.
2. Find the target type's closing brace: the first line that is exactly `}` (column 0) after the type's declaration line. Insert **above** it, not "at the end of the file".
3. Prefer an `extension` when the file is big or has several types: add `extension TripsListViewModel { ... }` explicitly named, with a `// MARK:`. It can't silently land in a neighboring type, and it can live in its own file (`TripsListViewModel+MapExit.swift`; one type/extension per file, named after it).
4. Check scope after the edit: view ~10 lines above and below the insertion; confirm indentation matches the intended type (members are indented 4 spaces; a method at 4 spaces after `}` at column 0 belongs to the *next* declaration above).
5. Count braces for the file: `python3 - <<'PY'` is overkill; quick check `grep -o "{" f | wc -l` vs `grep -o "}" f | wc -l` (ignores strings/comments, but a mismatch of 1 is the classic failure - see commit 4b5b98c "Fix brace mismatch in ListPlacesScrollView").
6. Grep the callers: `grep -rn "clearTrips(" loc` and confirm each receiver is the type that now owns the method.

## Checks
- [ ] Every new method's receiver type matches the call sites.
- [ ] The surrounding type's isolation (`@MainActor` or not) is what the method needs.
- [ ] Brace counts balance; indentation is consistent.

## Example
Wrong (appended to file end):
```swift
enum TripTimeline {
    static func split(...) -> ... { ... }
    func clearTrips(_ ids: [String], on c: MapDisplayCoordinatorViewModel) { ... }  // not a member of the view model!
}
```
Right: put it inside `TripsListViewModel` (before its closing `}`), or `extension TripsListViewModel { func clearTrips... }`.
