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

## Cross-check 2 — vanilla axe tag and tool action contract (2026-11-13)

The vanilla API reference for the `axe` prefab (build 714014, last updated 2026-03-04) lists the axe family as using the `tool`, `finiteuses`, `weapon` and `equippable` components, and explicitly lists `possessable_axe` among its tags. Its overview covers standard, golden and moonglass axe variants.

The `Tool` component reference states:
- `SetAction(action, effectiveness)` registers a supported action and adds the action-specific `<action.id>_tool` tag.
- `CanDoAction(action)` reports whether the tool supports that action.
- Tool durability changes can emit `toolbroke`; the crafting requirement must not consume durability.

The `InventoryReplica` reference exposes `HasItemWithTag(tag, amount)`, which delegates to the authoritative inventory on master and to the classified inventory data on clients. It is a plausible client-side availability primitive for a replicated, stable axe-family tag. The same API reference also exposes `EquipHasTag(tag)` for equipped tools.

References:
- https://vietnd69.github.io/dst-api-webdocs/docs/game-scripts/prefabs/axe
- https://vietnd69.github.io/dst-api-webdocs/docs/game-scripts/components/tool
- https://vietnd69.github.io/dst-api-webdocs/docs/game-scripts/components/inventory_replica
- https://vietnd69.github.io/dst-api-webdocs/docs/game-scripts/components/builder_replica

### Revised narrow implementation hypothesis (still not runtime-approved)

- For vanilla axes, prefer the explicit `possessable_axe` tag for client menu availability rather than relying on the dynamically generated action tag. Do not assume the action-specific tag is replicated merely because the server Tool component adds it.
- On the server, enumerate candidate items in the player's inventory/equipment and require a real `components.tool:CanDoAction(ACTIONS.CHOP)` check. The stable tag can narrow the candidate set, but must not replace the component check.
- For modded axes, support explicit opt-in through the vanilla `possessable_axe` tag or a MAM registration API; never infer support from prefab-name fragments.
- A reusable Stone-Carving Chisel needs its own explicit MAM tag present before network pristine, plus a server-side item-presence check. It should have no finite-use consumption path. Its prefab, inventory behavior and client tag visibility still need a dedicated test.
- A final server gate must cover buffered builds as well as ordinary builds. A client `HasIngredients` wrapper is only a menu-availability aid and is not a security boundary.
- Freebuild mode needs an explicit product decision: either waive the tool requirement consistently or preserve it consistently in both menu and server paths. Do not let the client and server disagree.

### Remaining evidence gaps

1. The cited axe prefab page is based on build 714014, while the Builder Replica and Inventory Replica pages are based on build 722832. They are community-generated API references, not the user's installed game files.
2. The docs establish that `possessable_axe` is a vanilla axe tag, but do not prove its live network visibility in the exact current DST build or UM Beta.
3. The inventory replica docs describe `HasItemWithTag`, but do not fully specify every nested-container/overflow edge case for tool lookup.
4. The chisel has no verified vanilla equivalent; it must be treated as a MAM-owned reusable item, not guessed from an unrelated prefab.
5. No production code, recipe, or third-party mod was changed by this cross-check.


## Cross-check 3 — client replica behavior and inventory/equipment coverage (2026-11-13)

A direct read of the public community mirror's `builder_replica.lua` clarifies the exact client behavior:

- `BuilderReplica:HasIngredients(recipe)` delegates to the master builder when `inst.components.builder` exists; on a remote client it resolves string recipes with `GetValidRecipe`, returns `true` immediately in free-build mode, then checks only `recipe.ingredients`, `recipe.character_ingredients` and `recipe.tech_ingredients`.
- There is no `recipe.canbuild` invocation in that method.
- `InventoryReplica` exposes `GetItems()` and `GetEquips()` separately, and documents `HasItemWithTag(tag, amount)` and `EquipHasTag(tag)`. Therefore, a client-side check must account for both carried and equipped tools; relying on `HasItemWithTag` alone is not enough to prove equipped-tool handling.
- The mirror's master `Builder:DoBuild` checks `recipe.canbuild` before it consumes ingredients. It also handles buffered builds, so the server gate is reached for buffered builds even when the normal ingredient check is bypassed.

Exact source inspected:
- https://raw.githubusercontent.com/taichunmin/dont-starve-together-game-scripts/master/scripts/components/builder_replica.lua
- https://raw.githubusercontent.com/taichunmin/dont-starve-together-game-scripts/master/scripts/components/builder.lua

### Product decision for freebuild

Tool requirements are waived in freebuild mode, matching the vanilla crafting model. This exception must be applied identically in the client menu predicate and the server-side `canbuild` predicate. The normal material ingredients are already waived by the replica's freebuild early return; a MAM tool predicate must not create a client/server mismatch.

### Safer implementation shape

1. Register only the MAM-owned recipes `boards` and `cutstone` (or the final replacement recipe IDs after recipe audit) in a narrow requirement registry.
2. Client availability: preserve the original `HasIngredients` result and return values; only after it succeeds, check the required tag in carried inventory and equipped slots. Treat missing replica/classified state as unavailable rather than guessing.
3. Server final gate: in `recipe.canbuild`, waive only for freebuild; otherwise inspect authoritative carried/equipped items and require a live `tool:CanDoAction(ACTIONS.CHOP)` for an axe. A tag alone is not sufficient.
4. Chisel: require a dedicated MAM prefab/tag and an explicit registration entry. Do not add a durability component or call finite-use consumption for this crafting requirement.
5. Any candidate tool moved, dropped, broken or transferred after the menu opens must fail at final server validation.
6. The inventory replica docs do not establish whether `HasItemWithTag` includes open/nested/overflow containers in every case. Prefer direct `GetItems` + `GetEquips` for exact candidate checks if those lists expose replicated item entities in the tested build; otherwise explicitly document and test the supported inventory scope.
7. Before wiring any global method wrapper, verify the actual modutil registration hook and load order for both master Builder and Builder Replica in the target build. The current branch's `modmain.lua` already imports `components/builder`, but that alone does not establish safe client replica registration.

### Implementation status after this cross-check

No runtime code has been changed. This research narrows the design and identifies a viable client API surface, but the following gates remain open: target-build source parity, the exact registration hook/load order, replicated equipped-item visibility, inventory/overflow behavior, and the chisel prefab's pre-pristine tag setup. Do not claim the axe/chisel requirement is implemented until those are covered by focused harnesses and an in-game client/server test.
