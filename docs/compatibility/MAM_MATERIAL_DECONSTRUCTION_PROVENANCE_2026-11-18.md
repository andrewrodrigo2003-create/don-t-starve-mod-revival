# Metals and More Reforged — material deconstruction provenance audit

**Date:** 2026-11-18  
**Status:** implemented as an explicit audit registry and regression contract in draft PR #65; not yet CI-validated or tested in-game.

## Scope and sources

The audit covers the material prefabs used by MAM's material progression. This includes the vanilla `goldnugget` input as well as MAM-defined material prefabs:
- `scripts/prefabs/metals.lua`
- `scripts/prefabs/metal_dusts.lua`
- `scripts/prefabs/gem_shards.lua`
- `scripts/prefabs/sharkscale.lua`

Reverse provenance is checked against `scripts/smelting_products.lua` and the existing `scripts/mam/deconstruction.lua` return rules. The transient legacy `gold_ore` conversion prefab is a save-migration shim, not a deconstruction material.

## Inventory

| Material | Disposition | Reason |
|---|---|---|
| `copper_ore`, `iron_ore`, `goldnugget` | Recoverable | Explicit registered material returns |
| `copper_ingot`, `iron_ingot`, `gold_ingot` | Recoverable | Explicit smelting-product reverse rules |
| `bronze_ingot` | Recoverable | Explicit copper/iron alloy inputs |
| `moonglass_ingot` | Recoverable | Explicit lunar material and moon inputs |
| `adamantium_ingot` | Recoverable | Existing explicit shadow/iron return profile |
| `copper_dust`, `iron_dust`, `gold_dust` | Excluded: raw input | No safe lower MAM conversion |
| `junk_dust` | Excluded: mixed by-product | Generic output from mixed metal loads; source cannot be reconstructed |
| Six gem shards | Excluded: raw gem material | Loot inputs; no safe MAM shard-to-whole-gem reverse recipe |
| `sharkscale` | Excluded: raw creature material | Harvested ingredient without a MAM processing recipe to reverse |

**Coverage:** 20 material prefabs classified; 9 remain eligible for the existing recovery action and 11 remain intentionally unsupported. This is complete audit coverage, not a claim that every material can be dismantled.

## Safety rules

- Do not infer reverse recipes from names, tags, or visual similarity.
- Do not turn raw dust or gem shards into a more valuable whole material.
- Do not invent component origins for `junk_dust` from mixed loads.
- Keep the existing recovery quantities, character rates, server authority, War Bench requirement, and output-capacity reservation unchanged.
- Weapons, armor, tools, equipment, and structures remain unsupported.

## Regression contract

`dst-mods/tests/metal_deconstruction_test.lua` checks that:
1. the audit registry contains exactly the known 20 material prefabs;
2. every material has a non-empty disposition and rationale;
3. the recoverable allowlist agrees with the audit status;
4. a newly introduced material cannot silently remain unclassified.

## Validation limits

PR #65 is a draft stacked on the CI-enabled base derived from PR #60. No CI run/check was returned for its current HEAD at the time of this audit. No DST runtime, multiplayer, save/load, or Uncompromising Mode Beta validation is claimed.
