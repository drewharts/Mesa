# Skill: explicit types where the compiler needs them

## When to use
CI/Xcode reports `The compiler is unable to type-check this expression in reasonable time`, `Generic parameter 'X' could not be inferred`, `Type of expression is ambiguous without a type annotation`, `Cannot convert value of type ...`, or you are writing a long `body`, a long modifier chain, a big literal, or mixed numeric math.

## Rules
1. **Stored properties always have a type.** `let allowsGrid: Bool` - not `let allowsGrid` (commit ddc2d58 fixed exactly that).
2. **Empty literals need a type**: `var items: [Item] = []`, `let cache: [String: [Post]] = [:]`, `@Published var error: String? = nil`.
3. **Complex closures get explicit signatures** when they have multiple statements or generic results: `{ (a: Place, b: Place) -> Bool in ... }`, `.map { (p: Place) -> Row in ... }`. A single-expression closure rarely needs it.
4. **Don't pass a method with default parameters as a function reference**: `rows.compactMap(Self.makeList)` failed; use `rows.compactMap { Self.makeList($0) }` (commit 6622765).
5. **Don't mix numeric types in one expression**: `CGFloat(count) * 0.5 + Double(x)` is a type-checker bomb. Convert up front into typed `let`s: `let width: CGFloat = ...`.
6. **Break up big view bodies.** A `body` with a long modifier chain (many `.onChange`, `.sheet`, `.overlay`) can blow the type-checker. Extract `private var header: some View { ... }`, move `.onChange` handlers into a `ViewModifier` (commit b22f1b7: `TripMapExitModifier`), or fold two `.onChange` handlers into one (commit 0065a6e, `MapContainerView`). Keep one View type per file (extract subviews into their own files).
7. **Optional/ternary chains**: split `a ?? (b ? c : d) ?? e` into named `let`s.
8. When an error points at a line in `body`, comment out halves (mentally) - the culprit is usually the **last modifier added**, not the line reported.

## Checks
- [ ] No untyped `let x` / `var x` without initializer.
- [ ] Any `body` you grew past ~40 lines/10 modifiers was split.
- [ ] No arithmetic mixing `Int`, `Double`, `CGFloat` without explicit conversion into typed locals.

## Examples (all real Mesa fixes)
- ddc2d58: restored `: Bool`.
- 6622765: `compactMap { Self.makeList($0) }`.
- 0065a6e / b22f1b7: moved `.onChange` logic out of the long `MapContainerView` body.
