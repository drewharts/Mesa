# Skill: main-actor isolation in Mesa

## When to use
Writing or editing a ViewModel, a service callback, anything `async`, or when CI reports an isolation/Sendable error (Xcode 26, Swift 6 toolchain; the app target uses default MainActor-leaning settings, so surprises show up as errors only in the archive build).

## Rules (match what `loc/ViewModels` already does)
1. **UI state lives on the main actor.** Every ViewModel is `@MainActor class X: ObservableObject` with `@Published` state. Example: `loc/ViewModels/Trips/TripsListViewModel.swift` (`@MainActor class TripsListViewModel: ObservableObject`). Views never mutate `@Published` from background code.
2. **Call async services with `await` from the ViewModel**, inside a `Task { ... }` started from a MainActor context. The Task inherits the actor, so state writes after the `await` are already on main. Do not wrap them in `DispatchQueue.main.async`.
3. **Callbacks from non-isolated APIs** (Google Sign-In, URLSession completion, delegates) hop back explicitly: `Task { @MainActor in self.errorMessage = ... }` (see `loc/ViewModels/LoginViewModel.swift:94-108`).
4. **Don't mix `DispatchQueue.main.async` with `Task`/`await`** in one function. Pick structured concurrency. Use `MainActor.run { }` only inside a non-isolated task or `Task.detached` (see `DetailPlaceViewModel.swift` ~229).
5. **CPU/IO helpers that must run off-main are `nonisolated`.** In a `@MainActor` type, a plain `static func` is main-actor isolated and cannot be called from a detached task or task group. Mark pure helpers `nonisolated static func` (commit c3d4841: `PhotoImportViewModel.extractGPSCoordinates`; `GoogleMapsImportViewModel.resolveOne/addOne` are `private nonisolated static`; `RecentlyImportedViewModel.boundingBox`). A nonisolated function may not touch `self`'s isolated state; pass values in as parameters.
6. **Concurrency fan-out**: use `withTaskGroup(of: Void.self)` with separate loader methods per section (CLAUDE.md "Progressive Loading"; see `CityDetailViewModel.swift:78`). Each child awaits a `nonisolated`/Sendable worker and the results are applied on the main actor after.
7. **Sendable**: values crossing task boundaries must be Sendable (structs of Sendable fields, enums). Don't capture a ViewModel in a `@Sendable` closure; capture the needed values. `@unchecked Sendable` is used rarely and only for lock-protected caches (`PlaceTimeZoneCache`, `BackgroundTaskBox`); do not add new ones without a comment saying what protects the state.
8. Singletons/services that are `ObservableObject` and published to Views are `@MainActor` too (e.g. PostsCacheService pattern in CLAUDE.md).

## Common errors -> fix
| Error text | Fix |
|---|---|
| `Call to main actor-isolated instance method 'x' in a synchronous nonisolated context` | Call from `Task { @MainActor in ... }` or make the caller `@MainActor`. |
| `Call to main actor-isolated static method 'x' in a synchronous nonisolated context` | The static helper is pure: mark it `nonisolated static func` (c3d4841). |
| `Main actor-isolated property 'p' can not be referenced from a Sendable closure` / `from a nonisolated context` | Read it first into a local `let` on the main actor, capture the local. |
| `Capture of 'self' with non-sendable type 'X' in a '@Sendable' closure` | Don't capture self; capture values, or run the closure on `@MainActor`. |
| `Sending 'x' risks causing data races` | Make the type a Sendable struct/enum, or keep the work on one actor. |
| `Expression is 'async' but is not marked with 'await'` | Add `await`; the caller must be async or inside `Task`. |
| `'async' call in a function that does not support concurrency` | Wrap in `Task { await ... }` from the ViewModel (not from a View body). |

## Checks
- [ ] New ViewModel has `@MainActor` directly above the class.
- [ ] No `DispatchQueue.main.async` added to a ViewModel that is already `@MainActor`.
- [ ] Helpers called from `Task.detached` / task groups are `nonisolated`.
- [ ] No state captured from `self` inside `nonisolated` functions.

## Examples
- Good: `loc/ViewModels/GoogleMapsImportViewModel.swift` keeps state mutations in the VM and runs bounded-concurrent resolve/add via `private nonisolated static func resolveOne(...)`.
- Bad: adding `static func extractGPSCoordinates` to a `@MainActor` class and calling it from `Task.detached` (broke the archive build, c3d4841).
