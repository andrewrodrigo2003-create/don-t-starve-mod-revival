# DST Compatibility and Release Test Matrix

This matrix records what was tested, against which versions, and at which evidence level. Update it for each release candidate.

## Evidence levels

| Level | Meaning | What it proves |
|---|---|---|
| L0 — Static | Source inspection, references, diff review | Identifies suspicious patterns; does not prove runtime behavior |
| L1 — Syntax | Lua 5.1 parser | Files are syntactically valid for Lua 5.1 |
| L2 — Harness | Real project module with controlled DST API stubs | Covered module behavior under the harness contract |
| L3 — Game API | Extracted DST scripts / API contract harness | Calls and assumptions match the inspected game scripts |
| L4 — In-game | Actual DST world | Tested behavior in the recorded game build and mod set |
| L5 — Multiplayer | Host/dedicated server + client, save/load and reconnect | Tested distributed and persistent behavior for the recorded scenarios |

A pass at one level never implies a pass at a higher level.

## Minimum scenario matrix

| Scenario | Required checks | Evidence |
|---|---|---|
| Vanilla + Metals and More | Startup, prefab registration, crafting, combat, drops, structures | L1–L4 |
| Uncompromising Mode Beta + Metals and More | Recipes, loot, tags, containers, tech, UI, load order | L1–L4 |
| Better Wood Skill Tree + Metals and More | Woodie initialization, movement/collision if relevant, skills, stategraph interactions | L1–L4 |
| User's full modpack | Startup, world generation, first load, save/load, reported crash paths | L1–L5 where applicable |
| Spell system | Unarmed, vanilla weapon, mod weapon, server validation, resources/cooldowns | L1–L5 |
| Smelting/forging | Single and batch recipes, ambiguous inputs, fuel/time, interruption, full output inventory | L1–L5 |
| Storage | Insert/remove, filter, destruction, full inventory, save/load, ownership | L1–L5 |
| Drops | Each source, each toggle, additive/Rewrite policy, rarity and repeated rolls | L1–L4 |
| Client/server | Host, dedicated server, client, late join, disconnect, stale RPC | L2–L5 |
| Optional integrations absent | Missing APIs/components/prefabs/config values | L2–L4 |

## Compatibility report template

- Release candidate / commit:
- DST build and branch:
- Metals and More version:
- External mod IDs and versions:
- Load order:
- Server type:
- Test world:
- Scenarios executed:
- Passed:
- Failed:
- Not run:
- Known conflicts:
- Crash log references:
- Performance observations:
- Verdict: Pass / Partial / Fail / Inconclusive

## Release gates

A release must not be described as universally compatible. Use a scoped verdict:
- **Pass:** all required scenarios for the stated target matrix have fresh evidence.
- **Partial:** focused checks pass, but one or more required runtime/multiplayer scenarios are not available.
- **Fail:** a reproducible critical defect remains.
- **Inconclusive:** logs, versions or reproduction data are insufficient.

## Current baseline (2026-11-09)

The repository already contains Lua 5.1 CI and several focused harnesses for smelting, forecast, lifecycle, stack settings, storage, loot Rewrite and weapon compatibility. The master plan records important in-game, UM Beta, multiplayer and save/load tests as pending. The current workflow trigger configuration must be reviewed: its push trigger names a single historical feature branch rather than `main`, so a push to `main` is not covered by that push trigger.
