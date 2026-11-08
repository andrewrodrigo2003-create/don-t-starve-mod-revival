# Metalurgy reference book and workstations — audit

Date: 2026-11-07  
Status: design/audit only; no recipe or station behavior changed by this document.

## 1. Reference book

### Requirements carried forward

- Read-only consultation of metal ores, dusts, shards, ingots, alloys, recipes, input requirements, output quantities, and smelting time.
- Show alternative outcomes when a mixed load can match multiple recipes; do not promise a deterministic result when the smelter uses weighted random selection.
- The book must not unlock recipes, add a prototyper tree, replace the smelter, or allow remote crafting.
- The book must not consume uses or sanity merely for consulting information.
- Provide English and Brazilian Portuguese strings.
- The authoritative recipe data must come from `smelting_products.lua` and `smelting.lua`, not a second manually maintained recipe list.

### Existing code found

- `scripts/prefabs/craftbook.lua` is an inventory prototyper: it adds the `prototyper` component and `TUNING.PROTOTYPER_TREES.CRAFTSBOOK_ONE`. Reusing it for the metallurgy guide would risk unlocking recipes and violate the read-only requirement.
- There is no dedicated metallurgy reference-book prefab in the current `PrefabFiles` list.
- The existing `mam/forecast.lua` already exposes recipe possibilities, output count, and smelting time for the furnace UI. A book can reuse a read-only data adapter around this module.

### API research and implementation direction

- DST's `book` component stores `onread`/`onperuse` callbacks and optional sanity/use behavior; it does not itself provide a multi-page recipe interface.
- DST's `simplebook` component invokes an `onreadfn` callback and is intended for simple readable items; it also does not provide a recipe catalogue UI.
- Therefore the reference book needs its own small read-only UI/screen or an equally clear inspectable page system. Do not add `prototyper`, `finiteuses`, or sanity costs.
- The UI should request/read recipe data only; all smelting and crafting remain at their existing stations.

References:
- DST Book component: https://vietnd69.github.io/dst-api-webdocs/docs/game-scripts/components/book
- DST Simplebook component: https://vietnd69.github.io/dst-api-webdocs/docs/game-scripts/components/simplebook
- DST vanilla book prefab patterns: https://vietnd69.github.io/dst-api-webdocs/docs/game-scripts/prefabs/books
- Current mod source: `scripts/mam/forecast.lua`, `scripts/smelting.lua`, `scripts/smelting_products.lua`

## 2. Workstation and recipe audit

### Existing structures and tabs

- `metal_smelter`: actual smelting station.
- `warworkbench`: existing prefab named “Armory”, registered through `AddPrototyperDef` with `is_crafting_station = true`, `action_str = "WARWORKBENCH"`, and `filter_text = "War bench"`. Its prototyper tree is `TUNING.PROTOTYPER_TREES.ALCHEMY_ONE`.
- `craftbook`: separate portable prototyper using `CRAFTSBOOK_ONE`; it is not a substitute for the warworkbench.
- `modded_forgepack.lua`: registers a recipe tab named “The Forge Event” for the four Forge weapons. This is a recipe tab, not a separate prefab station.

### Current metal/weapon recipes located in modmain

The following recipes are currently registered under the `forge_weapons` option and use `TECH.ALCHEMY_ONE` with the `CRAFTING_STATION` filter:
- `forginghammer`
- `pithpike`
- `spiralspear`
- `blacksmith_edge`

Other metal-related equipment currently registered with `TECH.ALCHEMY_ONE` includes `armor_sanity`, `nightsword`, `jagged_armor`, `halberd`, `scepter`, and `forkstick`.

### Open audit points — do not guess

- The current repository has a `warworkbench` prefab and a “The Forge Event” recipe tab, but the original request distinguishes a “bancada de armas” from a “bancada de guerra”. The current prefab list does not show a second explicit weapon-workbench prefab. Preserve both existing systems until the original intended mapping is confirmed from the v2.9.3 source/reference assets.
- Verify whether `CRAFTING_STATION` and `ALCHEMY_ONE` make each recipe available at the intended station in the live DST recipe UI. Do not assume that a recipe being assigned `ALCHEMY_ONE` proves it is exclusive to `warworkbench`.
- Inventory every recipe currently available at the science machine, alchemy engine, warworkbench, craftbook, and Forge tab before moving anything.
- Only move recipes explicitly intended for the warworkbench. Keep weapon recipes and the existing Forge tab intact unless the source and original request show otherwise.
- Preserve the original ingredient counts and tech progression. Use `mam/recipe_guard.lua` to avoid overwriting another mod's changed recipe ingredients.
- Add multiplayer and recipe-filter checks before considering the station work complete.

## 3. Next implementation order

1. Recover/compare the original v2.9.3 recipe and station definitions.
2. Produce a recipe-to-station matrix with original ingredients, tech tier, current station, intended station, and compatibility notes.
3. Build the metallurgy book UI as a read-only client presentation backed by the existing recipe data.
4. Only then adjust recipe filters/tech requirements for the warworkbench, with no duplicate recipe registration.
