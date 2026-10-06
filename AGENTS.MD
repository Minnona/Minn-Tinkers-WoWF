# WoW Forever Addon Rules

Target **World of Warcraft: Forever** unless explicitly told otherwise.

Optimize for correctness, simplicity, low runtime overhead, and small diffs. Do not add Retail/Classic compatibility unless requested.

## Implementation

Make the smallest correct change that satisfies the request.

Prefer, in order:

1. Reuse existing addon code.
2. Use Blizzard APIs/native UI functionality.
3. Use Lua/WoW built-ins.
4. Use an already-installed dependency.
5. Write minimal custom code.
6. Add a dependency only when clearly justified.

Follow YAGNI.

Do not add speculative:
- abstractions
- compatibility layers
- managers/services/factories
- generic event buses
- configuration
- extension points
- extra features

Prefer boring, idiomatic Lua over clever code.

Prefer deletion and simplification over addition, but never sacrifice correctness, security, saved-data integrity, accessibility, or required combat restrictions.

Do not code-golf merely to reduce LOC.

## Before Editing

Read the `.toc` when repository structure is unknown.

Search before writing new code.

Inspect only the files relevant to the task and trace the actual flow before changing it.

For bugs, find the root cause. If several callers share broken logic, fix the shared logic rather than patching each symptom.

Do not map or study the entire repository for a localized change.

Stop gathering context once the implementation path is clear.

## WoW APIs

Use the APIs available in the current Forever client.

When an API signature or behavior is uncertain, verify it rather than guessing from historical WoW knowledge.

Prefer:
- Blizzard events over polling
- Blizzard/native UI over custom replacements
- `HookScript` / `hooksecurefunc` over invasive function replacement
- current Blizzard APIs and `C_*` namespaces where appropriate

Do not rewrite a working API call solely because a newer equivalent exists.

Do not scrape UI text when a proper API provides the value.

## Combat and Protected APIs

Respect combat lockdown, secure frames, taint rules, and protected/secret values.

Never attempt to work around Blizzard addon restrictions.

Do not use protected/secret values for comparisons, arithmetic, branching, or automated decisions unless the current API explicitly permits it.

If a requested feature is impossible under Forever's addon restrictions, explain that instead of implementing a broken approximation.

Only add `InCombatLockdown()` / `PLAYER_REGEN_ENABLED` handling when the affected operation actually requires it.

## Performance

Prefer events over `OnUpdate`.

Use `OnUpdate` only for genuinely frame-time-dependent behavior such as animation.

Prefer `C_Timer` for delayed/periodic work when no suitable event exists.

In frequently executed code:
- return early for irrelevant events
- avoid unnecessary table/string allocations
- avoid rescanning all state when the event identifies what changed
- avoid updating unchanged UI
- avoid unnecessary work on hidden frames

Optimize hot paths, not one-time initialization code.

Do not add caching, throttling, or indexing without an actual need.

## Lua

Follow existing repository style.

Otherwise:
- prefer locals over globals
- use the addon namespace from `...` where appropriate
- prefer plain tables and functions
- keep related logic together
- avoid OOP/metatables/frameworks unless clearly useful
- do not create helpers used only once unless they improve clarity
- do not split small features across unnecessary files

## Dependencies and UI

Do not introduce Ace3, LibStub libraries, or other frameworks merely to avoid writing a few clear lines of Lua.

Reuse existing dependencies when appropriate.

Prefer Blizzard frames, templates, widgets, settings APIs, and functionality over custom replacements.

Do not build custom dropdowns, settings frameworks, event dispatchers, serialization systems, or widget libraries when an existing solution already covers the task.

## SavedVariables

Keep persistent data simple.

Reuse the existing schema.

Do not add migration/framework machinery unless existing user data genuinely needs migration.

Never silently discard existing user settings.

Do not persist values that can cheaply and reliably be derived from game state.

## Editing

Keep diffs focused.

Do not:
- reformat unrelated code
- rename unrelated symbols
- reorder unrelated functions
- refactor unrelated code
- change documentation/versioning unless required
- turn a bug fix into a rewrite

Preserve surrounding style.

## Verification

Use the narrowest useful verification first.

Reuse existing lint/static-analysis/package tooling when available.

Do not introduce a test framework for a small addon change.

For non-trivial pure Lua logic, add the smallest useful regression check when practical.

Never claim something was verified in-game unless the client was actually run.

When in-game verification is required, state the minimal steps, usually:

`/reload` → trigger behavior → check Lua errors → verify result.

Test combat behavior when the changed feature is combat-sensitive.

## Context Efficiency

Use targeted searches and reads.

Do not repeatedly reread unchanged files.

Do not inspect vendored libraries unless relevant.

Do not spawn subagents for simple/localized work.

Do not generate long implementation plans for straightforward tasks.

## Response

After completing work, report concisely:

- what changed
- what was verified
- any important limitation or required in-game test

Do not suggest unrelated improvements.

## Priority

When rules conflict:

1. Correctness
2. WoW API/security/combat restrictions
3. Explicit user request
4. Existing repository conventions
5. Simplicity
6. Runtime efficiency
7. Fewer lines/files

The goal is the least code worth owning.

## Publishing

Work locally. Push commits or publish GitHub updates only after the user explicitly approves them.

The GitHub repository is Minnona/Minn-Tinkers-WoWF; the addon folder and TOC remain `Minn Tinkers WoWF`.

When new features go live, bump `## Version` in `Minn Tinkers WoWF.toc` before pushing the release to `main`. Use a new numeric version (for example, 1.1 or 1.1.1); never reuse a published version. The release workflow tests the addon and packages the stable `Minn-Tinkers-WoWF.zip` asset with a single `Minn Tinkers WoWF/` folder. Keep the README concise and its latest-ZIP link at the beginning.
