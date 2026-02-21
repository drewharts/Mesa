---
name: whats-new
description: Show customer-facing changes since the last app version bump for App Store "What's New" notes
disable-model-invocation: true
user-invocable: true
allowed-tools: Bash(git *), Read, Grep, Glob
---

## What's New - App Store Release Notes Generator

Generate customer-facing "What's New" notes by analyzing changes on main since the last version bump (archive point).

### Steps

1. Find the two most recent "Bump version" commits on main:
   ```
   git log --oneline main | grep -i "bump.*version\|version.*bump"
   ```

2. Use the **second** bump commit (the previous archive) as the base, and show all commits between that and HEAD:
   ```
   git log --oneline <previous-bump>..<latest-bump-or-HEAD>
   ```

3. For each commit, read the commit message and (if needed) the diff to understand the user-facing change.

4. **Filter out non-user-facing changes** like:
   - Version bumps themselves
   - Refactors with no visible behavior change
   - Internal code cleanup
   - CI/build config changes
   - Developer tooling changes

5. **Group and summarize** the remaining changes into customer-friendly categories:
   - New Features
   - Improvements
   - Bug Fixes

6. **Write the output** in App Store "What's New" style:
   - Short, friendly, non-technical language
   - Use bullet points
   - No code references, file names, or technical jargon
   - Focus on what the user sees/experiences
   - Keep it concise (aim for 3-8 bullet points total)

### Output Format

```
Version X.XX

- [Bullet point describing user-facing change]
- [Bullet point describing user-facing change]
...
```

If $ARGUMENTS is provided, use it as the version number. Otherwise, read the current version from the latest bump commit.
