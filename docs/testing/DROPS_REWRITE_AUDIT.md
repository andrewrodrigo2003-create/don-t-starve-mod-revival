# Ore drops — Rewrite mode audit

Date: 2026-11-07  
Branch: `fix/rewrite-drops-source-options`  
Pull request: #6 (carried forward for runtime validation in a new PR)

## Defects found

1. `newrocks.lua` wrapped all 18 vanilla loot-table replacements in one master/mode condition. The per-source switches for boulders, stalagmites, chess pieces, and hounds were not checked in Rewrite mode. Turning a source off therefore did not actually disable its rewritten tables.
2. `MAMLootGuard.state()` skipped every `AddChanceLoot` source in Rewrite mode. The marble tree and shark extras historically used entity-level chance rolls rather than one of the 18 shared tables, so those extras disappeared in Rewrite mode.
3. Hound handling needed to preserve the documented Auto/Always behavior with Uncompromising Mode: Auto must yield to UM; Always must add our shards without replacing UM's loot table.

## Changes

- Added per-source gates for the boulder, stalagmite, and chess table groups.
- Kept all 18 original table definitions and their entry values unchanged.
- Routed Rewrite table definitions through the same optional `PrepareEntries` normalization used by additive drops.
- Restored marble-tree and shark entity-level rolls in Rewrite mode through an explicit `apply_in_rewrite` source option.
- Hounds in Rewrite mode now resolve after other mod initialization:
  - UM absent + source enabled: restore the original v2.9.3 shared tables.
  - UM present + Auto: do not replace or add hound drops.
  - UM present + Always: add our shard rolls through `AddChanceLoot`, preserving UM's own table.
  - Source disabled: no Metals and More hound rolls.

## Verification performed

- Static checks confirmed each Rewrite source group is gated by its own config key.
- Static checks confirmed the shared normalization helper is exported and used by Rewrite tables.
- Static checks confirmed marble-tree and shark declarations explicitly opt into Rewrite-mode additive handling.
- Compared all 18 vanilla table definitions in `newrocks.lua` before and after the change: all 18 names and every `{ prefab, chance }` entry match exactly; no probability or entry was changed.
- Reviewed the hound decision paths against Auto/Always and UM-present/absent cases.
- Ran a LuaTeX harness containing an isolated copy of the drop-state decision logic: 9 cases passed (additive/rewrite, Auto/Always, UM present/absent, source disabled, and master switch off). This is a decision-logic harness, not execution of the full `loot_guard.lua` module or DST.

## Not tested

- Lua parsing of the complete changed source files in the DST Lua environment; the decision harness does not parse or load the full mod modules.
- Live loot generation, worldgen, save/load, multiplayer, or actual Uncompromising Mode Beta integration.
- The user's installed UM Beta version. These remain required in-game checks.


## Additional runtime verification — 2026-11-08

- Added `dst-mods/tests/loot_rewrite_runtime_test.lua`, which loads the real `mam/loot_guard.lua`, the actual `initialise/modded_drops.lua` declarations and `scripts/prefabs/newrocks.lua` with minimal DST registration stubs.
- Covers Rewrite source gates for boulders/stalagmites/chess/hounds, the 18 vanilla table registrations, marble-tree/shark additive exceptions, UM Auto/Always behavior, master/source switches, server authority and probability normalization.
- This remains a Lua harness with stubs, not live world loot generation or a full DST/UM integration test.
