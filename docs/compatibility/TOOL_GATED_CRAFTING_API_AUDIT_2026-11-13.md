# DST tool-gated crafting API audit

**Date:** 2026-11-13  
**Related milestone:** Metals and More Reforged 2.9.7  
**Status:** source-level research only; no gameplay implementation is approved by this note.

## Question

Can a recipe require an axe or a reusable stone-carving chisel as a tool without consuming that tool as an ingredient?

## Findings from the public DST script mirror

The inspected source mirror exposes two relevant mechanisms:

1. In `recipe.lua`, the recipe constructor stores `more_data.canbuild` as `recipe.canbuild`. This callback receives the recipe, builder, placement point and rotation.
2. In `components/builder.lua`, `Builder:DoBuild` calls `recipe.canbuild(recipe, self.inst, pt, rotation)` and aborts the build when the callback returns false.
3. In the same builder component, `Builder:HasIngredients` checks only ordinary inventory ingredients, character ingredients and tech ingredients. It does not call `recipe.canbuild`.

Sources inspected:
- https://github.com/taichunmin/dont-starve-together-game-scripts/blob/master/recipe.lua
- https://github.com/taichunmin/dont-starve-together-game-scripts/blob/master/scripts/components/builder.lua

**Source limitation:** this is a public community mirror, not an authenticated copy of the user's installed DST build or a Klei-published API contract. Its branch/build parity with the current DST release and UM Public Beta has not been established.

## Engineering consequence

A `canbuild` callback alone appears insufficient for the intended UX: it can reject the final server-side build, while the normal ingredient-availability path may still report that the recipe's material requirements are satisfied. That can leave a recipe looking craftable until the player attempts it.

Do not model an axe or chisel as a normal positive-count `Ingredient` unless consumption is intended. That would consume the tool and violate the accepted design.

## Required implementation gates

Before implementing the board and cut-stone changes:

1. Verify the same callback and builder flow against the exact DST scripts version available to the project, including the client replica/UI path and buffered-build path.
2. Select the smallest safe approach that gives consistent menu availability and final server-authoritative rejection. Avoid globally replacing builder methods if a recipe-scoped adapter can satisfy the contract.
3. Validate tool possession by stable vanilla tool tags/components and an explicit supported-tool registry; do not use prefab-name substring heuristics.
4. Revalidate at the moment of crafting on the server, so moving, dropping, breaking or transferring the tool between menu display and craft execution cannot bypass the gate.
5. Keep the tool unconsumed and do not charge durability merely for crafting unless the game-native mechanic explicitly requires it.
6. Test axe tiers, compatible modded axes, missing/broken tools, inventory containers, multiplayer ownership, buffered recipes, freebuild mode, and UM Beta load-order changes.
7. If the client-side availability contract cannot be verified, do not ship a misleading crafting-menu state; defer the feature or provide a clearly communicated, narrowly scoped fallback.

## Current decisions preserved

- Any valid axe tier should satisfy board crafting.
- The reusable Stone-Carving Chisel is infinite-use and not consumed.
- Do not modify Woodie's skill tree or copy its character-specific board discount.
- Do not assume a Sawing Table exists; verify its prefab and action API before adding integration.
- Do not edit UM, Hydrated/Dehydrated, Better Lucy or any other third-party mod.

## Next action

Inspect the exact game-version scripts and the client replica/UI implementation, then build a focused test harness before changing production crafting recipes. This note is research, not proof of runtime compatibility.


## Additional cross-check — client crafting replica documentation (2026-11-13)

The API documentation generated from game build 722832 (Builder Replica page last updated 2026-04-28) independently describes `BuilderReplica:HasIngredients(recipe)` as checking inventory, character and tech ingredients, with an early true result in free-build mode. It does not list or evaluate `recipe.canbuild`.

Reference:
- https://vietnd69.github.io/dst-api-webdocs/docs/game-scripts/components/builder_replica
- https://vietnd69.github.io/dst-api-webdocs/docs/game-scripts/components/builder

This confirms the key UX limitation in the inspected script mirror: a recipe-scoped `canbuild` check is a final server gate, not a complete client-side crafting-menu availability rule. A player can still see the recipe as craftable without the required axe/chisel, then be rejected only at the final build call.

Implementation direction (not yet approved for runtime):
- Keep tool requirements out of consumed recipe ingredients.
- A complete solution must check tool possession in both master Builder and client Builder Replica availability paths, and revalidate server-side at the final build.
- If this requires method wrappers, preserve the original return values, support both normal and buffered builds, and scope the extra predicate only to explicitly registered MAM recipes.
- Do not infer an axe from prefab-name substrings. Confirm exact vanilla tags/components and what the client replica can observe; if client-side verification cannot be made reliable, defer the feature rather than ship a misleading menu.
- Test freebuild mode, inventory and overflow containers, multiplayer, tool dropped/transferred between menu and build, invalid/broken tools, and modded axes with explicit supported tags.

**Evidence limit:** the API documentation's declared base is build 722832, and the community mirror is not the user's installed game files. This is strong design evidence, not proof of current-build compatibility. No production crafting recipe was changed by this audit.
