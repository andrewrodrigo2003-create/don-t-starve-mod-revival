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
- Smooth stone / cut-stone production must require either the chisel as an available tool or the in-game Sawing Table.
- The chisel is a tool requirement, not a consumed ingredient. It must not be possible to satisfy the recipe by carrying a broken/invalid substitute or by duplicating a crafted result through repeat callbacks.
- The Sawing Table provides the alternative processing route and must integrate with its actual vanilla/UM prefab and action APIs. Do not invent a prefab or assume a table exists without source verification.
- Audit all stone-family materials and outputs (rocks, flint, marble, cutstone, thulecite and modded stone-like materials) before changing costs. Do not force every stone material through one recipe if that damages progression.

## 4. Woodworking — boards require an axe or Sawing Table

- Board production requires a valid axe tool or the Sawing Table.
- Axe is a tool requirement and is not consumed. Preserve axe durability according to the game's normal tool-use conventions; do not make the new recipe consume an axe as an ingredient.
- Support vanilla axe tiers and compatible third-party axes through stable tags/components where possible. If a modded axe cannot be safely identified, it must not be accepted by an unsafe name heuristic.
- Sawing Table is the alternative route.
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
4. Implement non-consuming tool validation for chisel/axe and Sawing Table integration after verifying the real DST/UM APIs.
5. Produce the acquisition/processing/usage balance matrix for stone and wood; change recipes only with documented rationale.
6. Add compatibility adapters and source-contract tests for vanilla, UM Beta and representative modded recipes.
7. Run Lua 5.1 parsing, unit/contract tests, multiplayer/save-load checks where possible, and build a single consolidated package.
8. Keep the branch/PR draft until the user performs the in-game test. Do not merge or publish to Workshop without explicit approval.

## Out of scope for this milestone

New biomes, bosses, mobs, broad new item families, and new world structures. These belong to a later content expansion after the crafting foundation is stable.
