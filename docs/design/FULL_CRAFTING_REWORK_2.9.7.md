# Full Crafting Rework — Metals and More Reforged

**Target milestone:** 2.9.7 (after the 2.9.6 in-game test candidate)  
**Branch:** `feature/full-crafting-rework-localization-2026-11-12`  
**Status:** design baseline plus initial localization and material-only deconstruction changes; not yet gameplay-certified.

## Product direction

Metals and More Reforged is intended to be a complete rework of how crafting works in Don't Starve Together, not merely a metal-items expansion. The first scope is the existing vanilla material and crafting progression, integrated with Uncompromising Mode Public Beta and other mods. New biomes, bosses, mobs, items unrelated to the crafting system, and structures are explicitly deferred to a later expansion phase.

The 2.9.6 package remains a separate test candidate. This work is developed on a new branch so that the already-consolidated test build is not silently changed underneath the user's test.

## 1. Localization — Portuguese and English

- Ship complete Brazilian Portuguese (pt-BR) and English (en) localization for every MAM-owned item name, description, recipe description, station, book page, UI label, configuration option, action label, error and notification.
- Add a language setting with **Português (Brasil)** and **English**. Default: Portuguese (Brasil).
- Keep the selected language consistent across the server-owned mod configuration and all clients. Do not concatenate both languages into one string.
- Use the game's localization conventions and a single translation registry/module, with English as the fallback for missing third-party or future strings.
- Do not overwrite another mod's string keys. All MAM keys remain namespaced/prefixed where the game permits.
- Audit all current hard-coded English and bilingual strings, including the metallurgy guide screen; remove mixed-language output after localization is complete.
- Configuration UI labels must remain readable before the selected language is loaded; use a safe default and document any DST limitation in localizing mod configuration menus.

## 2. Material-only, character-aware deconstruction

Deconstruction applies to **all basic and intermediate materials owned by MAM**, never crafted equipment, weapons, armor, tools, or structures.

Required coverage includes every MAM material prefab, not only the current copper/iron/gold/bronze/moonglass/adamantium subset: dusts, ores, ingots/alloys, gem shards, by-products, and other registered raw/refined material items (including sharkscale where applicable). The final registry must be generated/audited against the actual prefab and recipe lists so no MAM material is silently omitted.

- Use reverse provenance from the live smelting/material recipe registry where available; preserve source material identity and prevent upward conversion or profitable loops.
- Handle tagged/alternative ingredients through the authoritative smelting planner, not a guessed fixed recipe.
- Each character must have an explicit resolved profile. Character-specific recovery must be based on actual in-game abilities, crafting knowledge, lore/mechanics, or a documented design rule. Do not grant arbitrary bonuses merely to make every character different.
- Current branch now resolves explicit profiles for the 18 currently listed vanilla survivors; Wilson, Winona and Maxwell retain the already established material-specific rules, while other survivors use the safe standard rate until a justified specialty is documented. Unknown modded survivors receive a safe generic fallback. The roster must be rechecked against the active DST build before release.
- Character profiles may affect recovery chance, eligible material classes, handling efficiency, or output form, but must never create materials from nothing or bypass recipe progression.
- Server-authoritative atomic operation: validate station/range, item ownership, output capacity and all planned returns before consuming. No free rerolls; no equipment salvage; no partial material loss if output delivery fails.
- UI/book must explain the active character's recovery rules and fallback behavior.

## 3. Stoneworking — smooth stone and the reusable chisel

- Add a new **Stone-Carving Chisel** item. It is a reusable, infinite-use tool: no durability consumption and no stack consumption on use.
- Smooth stone / cut-stone production must require the chisel as an available tool; the old vanilla crafting route for the replaced output is disabled/removed so the new tool-gated route is mandatory.
- The chisel is a tool requirement, not a consumed ingredient. It must not be possible to satisfy the recipe by carrying a broken/invalid substitute or by duplicating a crafted result through repeat callbacks.
- Sawing Table integration remains a separately specified alternative only where an actual vanilla/UM table prefab and action API are verified from source. Do not invent a prefab or assume a table exists. It must not silently restore the disabled vanilla route.
- Audit all stone-family materials and outputs (rocks, flint, marble, cutstone, thulecite and modded stone-like materials) before changing costs. Do not force every stone material through one recipe if that damages progression.

## 4. Woodworking — boards require any axe

- Board production requires a valid axe tool. Any valid vanilla axe tier must satisfy the requirement; do not restrict the recipe to one specific axe prefab.
- Axe is a tool requirement and is not consumed. Preserve axe durability according to the game's normal tool-use conventions; do not make the new recipe consume an axe as an ingredient.
- The old vanilla board crafting route is disabled/removed; boards must be produced through the new axe-gated route. The axe is required for every character.
- Make Woodie's existing board-cost reduction/woodworking skill effect a native, shared crafting rule available to every survivor, not a Woodie-only perk. Apply the exact existing vanilla discount/value after source verification; do not invent a new discount or modify Woodie's external skill-tree mod.
- Support compatible third-party axes through stable tags/components where possible. If a modded axe cannot be safely identified, it must not be accepted by an unsafe name heuristic.
- Sawing Table integration remains a separately specified alternative only where an actual vanilla/UM table prefab and action API are verified from source. It must not silently restore the disabled vanilla route.
- Audit logs, boards, living logs, driftwood, twig sources and UM-specific wood materials before rebalance. Preserve character and world-source differences.

## 5. Rebalance framework — wood and stone first

Every changed recipe/material must be scored on three separate axes:
1. **Acquisition difficulty:** source frequency, biome/access risk, enemy risk, tool/technology gate, and renewable vs finite source.
2. **Processing difficulty:** station, tool, time, fuel, crafting tier, skill/character gate, and material conversion loss.
3. **Usage pressure:** how often the material is required, quantity per recipe, progression importance, repair/maintenance demand, and whether it is consumed repeatedly.

Balance decisions must compare equivalent progression tiers and expected playtime, not simply make all recipe quantities equal. Record the baseline vanilla/UM recipe, proposed recipe, rationale, expected bottleneck, and regression tests. Do not rebalance metal costs incidentally while the wood/stone matrix is under review.

## 6. Dynamic integration and compatibility

- Read live `AllRecipes`, active prefab registrations, recipe filters, ingredient tags, prototyper trees and supported tool tags at runtime.
- Never replace a third-party recipe wholesale. Apply narrowly scoped, idempotent changes only when the live recipe still matches a known baseline or when an explicit compatibility adapter owns that integration.
- If UM Beta or another mod changed a recipe, preserve its ingredients and metadata while applying only the safe MAM processing gate where possible; otherwise yield and record the conflict.
- Compatibility adapters must be isolated by mod detection and version/capability checks, not hard dependencies.
- Do not edit Uncompromising Mode, Hydrated/Dehydrated, Better Lucy or other third-party source files.
- Unknown mods must fail safely: retain their recipe and do not crash world initialization.
- Add contract tests for load order, recipe mutation, tags, tool validation, multiplayer authority, missing prefabs, and fallback behavior.

## 7. Implementation sequence and release gates

1. Inventory all MAM material prefabs, recipes, strings, stone/wood recipes, tool tags, vanilla survivors and relevant UM Beta changes. The current reversible registry covers the copper/iron/gold/bronze/moonglass/adamantium progression; dusts, gem shards, junk dust and sharkscale still need provenance-based decisions before claiming complete material coverage.
2. Implement the localization registry and language selection; add complete string-coverage tests.
3. Replace the narrow deconstruction allowlist with a material-only registry and explicit character profile resolver; add full survivor/material coverage tests.
4. Implement non-consuming tool validation for chisel/axe and verified Sawing Table integration; remove the replaced vanilla board/cut-stone crafting routes without disabling unrelated recipes.
5. Produce the acquisition/processing/usage balance matrix for stone and wood; change recipes only with documented rationale.
6. Add compatibility adapters and source-contract tests for vanilla, UM Beta and representative modded recipes.
7. Run Lua 5.1 parsing, unit/contract tests, multiplayer/save-load checks where possible, and build a single consolidated package.
8. Keep the branch/PR draft until the user performs the in-game test. Do not merge or publish to Workshop without explicit approval.

## Out of scope for this milestone

New biomes, bosses, mobs, broad new item families, and new world structures. These belong to a later content expansion after the crafting foundation is stable.

## Clarification from user — tool-gated crafting (2026-11-12)

This clarification refines the existing full-update request; it does not replace the master plan or the prior requested feature list.

- **Boards:** disable the standard vanilla board recipe. All survivors must use the new tool-gated route. Any valid axe works and is not consumed. Use the actual vanilla Woodie board-cost reduction as the common baseline for every survivor; verify its exact value/implementation from the active DST source before coding. Preserve ordinary axe durability/use behavior and do not edit Woodie's skill-tree mod.
- **Cut stone:** disable the standard vanilla cut-stone route being replaced. Add a new reusable Stone-Carving Chisel item; it is a non-consumed tool requirement, with no durability or stack consumption. Follow the same shared rule for every survivor.
- **Sawing Table:** retain the previously requested alternative only if a real vanilla/UM implementation and API are verified. It cannot re-enable the disabled vanilla recipe path by accident.
- Both tool gates must be server-authoritative, validate a real equipped/carried tool by supported components/tags, reject broken/invalid tools, and fail closed for unknown third-party tools. Neither tool is consumed as an ingredient.
- This is a clarification only. The rest of the 2.9.7 scope and the master update/ideas map remain active and must continue to be implemented.


## Clarification from user — granular, independently configurable integrations (2026-11-12)

All compatibility and balance changes must be player-configurable at the smallest sensible feature boundary. Do not use one broad switch that disables unrelated MAM mechanics.

- Third-party recipe integration/modification is permitted, but must have its own setting, independently disableable. When disabled, preserve the live third-party recipe and metadata without MAM mutation.
- The third-party recipe setting must NOT disable MAM-owned mandatory axe-gated board crafting, reusable chisel-gated cut-stone crafting, or a verified Sawing Table route. These are separate MAM crafting mechanics with separate settings only if a player-facing toggle is appropriate; never couple them to third-party compatibility.
- Third-party drop integration/modification must have its own independent setting(s), separate from recipe integration. Preserve the other mod's drops when disabled; do not remove or replace its loot tables as a side effect.
- MAM-owned drop behavior must expose independent controls for relevant sources/categories and adjustable parameters such as chance and quantity/range where technically safe. Include sensible documented defaults and bounds; prevent invalid values, zero-cost loops, duplicate rolls and unintended farming exploits. Do not expose third-party drop tuning as if it were MAM-owned content.
- MAM-owned recipe/crafting rules, vanilla recipe replacement, mandatory tool requirements, Sawing Table support, third-party recipe adapters, third-party drop adapters, and MAM drop tuning must be separate settings domains. Each option's description must state exactly what it changes and what it does not change.
- Prefer the granular, category-by-category configurability exemplified by Uncompromising Mode: players should be able to keep integrations they like and disable only the changes they dislike.
- Settings must be safe under multiplayer: authoritative server configuration governs world mechanics; clients receive consistent state. Define behavior for world creation, existing saves, missing mods, load order and configuration migration. Defaults should preserve the intended MAM experience while avoiding destructive third-party overwrites.
- Add configuration contract tests proving each switch changes only its own feature boundary, including combinations of switches. Explicitly test that disabling third-party recipe integration leaves axe/chisel gates intact and that disabling third-party drop integration does not disable MAM's own drops.

This clarification expands configurability; it does not remove or replace any previously requested 2.9.7 feature or the master ideas map.
