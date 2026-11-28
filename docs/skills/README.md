# Mesa agent skills

Short, actionable playbooks for tasks where agents have failed before. Read the relevant one **before** you start the task. Each has: When to use / Steps / Checks / Examples.

| Skill | Use it when |
|---|---|
| [verify-mesa.md](verify-mesa.md) | You changed behavior and need to prove it works like a user would (CI, simulator, screenshots). |
| [swiftui-new-view.md](swiftui-new-view.md) | You are adding a SwiftUI view, modifier, or helper type. Prevents duplicate-type build breaks. |
| [main-actor.md](main-actor.md) | You touch a ViewModel, an async call, or get a concurrency/isolation compiler error. |
| [wrong-type-placement.md](wrong-type-placement.md) | You are inserting methods into an existing file that has several types (enum + class + extension). |
| [type-annotations.md](type-annotations.md) | The compiler says "unable to type-check this expression in reasonable time" or can't infer a type. |
| [version-bump.md](version-bump.md) | Anything about releases, `MARKETING_VERSION`, TestFlight, App Store, release notes. |
| [replay-testing.md](replay-testing.md) | (Plan only) How we will test changes to these skills by replaying past requests. |

Related: [../../AGENTS.md](../../AGENTS.md) (conventions), [../../FEATURE_MAP.md](../../FEATURE_MAP.md) (user-visible features -> files -> accessibility IDs), [../AGENT_NOTES.md](../AGENT_NOTES.md) (running log, decisions, open items).

Rule of thumb: there is **no Xcode on the agent box**. CI (`.github/workflows/checks.yml`) is the compiler. Every skill therefore favors small diffs and cheap static checks you can run locally with `grep`/`python3 ci/*.py` before pushing to a feature branch.
