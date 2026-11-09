# Metals and More Reforged — static source audit baseline

**Date:** 2026-11-09  
**Source:** repository main at the time of the audit; audit helper added in PR #25.  
**Method:** read-only scan of the mod directory. No scanned code was executed.

## Inventory
- Files: 237
- Lua files: 92
- Static indicators: 156
- Read errors: 0
- SHA-256 values recorded for each inventoried file in the CI artifact.
- GitHub Actions: audit-tool tests and source inventory job passed in run 42665325973.

Artifact: workflow run 42665325973, artifact name metals-and-more-source-audit (14-day retention).

## Signal distribution

| Category | Matches | Interpretation |
|---|---:|---|
| Mod detection and recipes | 77 | Recipe and mod integration entry points |
| Prefab/component hooks | 57 | Lifecycle and component extension points |
| Weapon/projectile hooks | 9 | Alternate attack/projectile code paths worth reviewing |
| Spell API | 7 | Spell-related component references; inspect exact component |
| Global mutation | 3 | Global environment changes worth reviewing |
| Dynamic code/debug | 3 | Environment/debug-related Lua primitives worth reviewing |
| Filesystem/process | 0 | No matching patterns found |
| Network/remote calls | 0 | No matching patterns found |
| Encoding/crypto indicators | 0 | No matching patterns found |

## Important source-level findings

1. A repository-wide GitHub code search for the exact identifier SetSpellFn returned no matches in Metals and More Reforged main.
2. The seven spell-related scanner matches are references to aoespell, OnSpellCast or SetAOESpell, not SetSpellFn.
3. blacksmith_edge.lua creates the aoespell component on the master simulation and calls SetAOESpell with its own callback.
4. pithpike.lua similarly adds aoespell and calls SetAOESpell; its weapon alternate attack is configured separately through SetAltAttack.
5. mod_main.lua defines Metals and More's SetAltAttack extension and retains an ignored legacy positional placeholder. This preserves argument positions but is not a projectile bridge.
6. The scanner flagged environment changes in modded_pithpikemove.lua and players_stategraph.lua (GLOBAL.setmetatable/GLOBAL.getfenv), and tot_ui.lua (GLOBAL.setfenv). These are code patterns to understand in context, not proof of malicious behavior.
7. No matching filesystem/process or network-call patterns were found by the current rule set. This does not prove absence of indirect, obfuscated, aliased or dynamically constructed behavior.

## What this does and does not establish

This is a reproducible static baseline of the current Metals and More source tree. It does not establish runtime safety, absence of hidden behavior, or in-game compatibility. It does not inspect the Better Wood Skill Tree source, the user's local Workshop files, the exact DST scripts.zip, or the six historical crash logs.

The historical Better Wood error referenced SetSpellFn at third-party modmain.lua:1405 during Lucy prefab creation. The present Metals and More main source does not contain that exact method call, so the next step is to inspect the exact third-party source and compare its call receiver/component lifecycle against the matching DST build. Do not conclude that Metals and More cannot be involved indirectly until its post-init hooks and load-order interactions are tested.

## Next tests
- Inspect exact Better Wood Workshop source and its version/hash.
- Inspect exact DST scripts.zip and component definitions for the game build associated with the crash.
- Trace Lucy prefab creation and any Woodie/skin/API callbacks.
- Build minimal reproduction permutations: Better Wood alone, Better Wood + implicated dependencies, then Metals and More added; vary load order one dimension at a time.
- Add a real-module integration harness and verify in-game after static analysis.
