---
name: bump-version
description: Increment the app marketing version by 0.01 in the Xcode project
disable-model-invocation: true
user-invocable: true
allowed-tools: Bash(git *), Read, Edit, Grep
---

## Bump Version

Increment the MARKETING_VERSION in the Xcode project file by 0.01.

### Steps

1. Read `loc.xcodeproj/project.pbxproj` and find all `MARKETING_VERSION` entries.

2. Parse the current version number (e.g. 4.50).

3. Increment by 0.01 (e.g. 4.50 -> 4.51).

4. Replace ALL occurrences of the old version with the new version in `project.pbxproj` using the Edit tool.

5. Confirm the change to the user by showing: `Version bumped: X.XX -> X.XX`

### Rules

- Do NOT commit or push. The user will test in Xcode first.
- Update every `MARKETING_VERSION` occurrence (there are multiple build configurations).
- Use two decimal places (e.g. 4.50, not 4.5).
