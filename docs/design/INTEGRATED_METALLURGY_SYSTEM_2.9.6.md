# Integrated metallurgy systems — build 2.9.6

**Status:** implementation in the 2.9.6 test branch; awaiting in-game validation.  
**Target:** DST API 10.  
**Do not treat CI as in-game certification.**

## 1. War Bench crafting matrix

The following existing vanilla recipes are moved into the War Bench filter by changing only their live technology requirement to `TECH.ALCHEMY_ONE` and adding them to `CRAFTING_STATION`:

- Tools and utility: `goldenaxe`, `goldenpickaxe`, `goldenshovel`, `golden_farm_hoe`, `compass`, `razor`, `multitool_axe_pickaxe`.
- Metal structures and devices: `birdcage`, `dragonflychest`, `lightning_rod`, `winterometer`, `rainometer`, `nightlight`.
- Armor: `armormarble`, `armordragonfly`, `ruinshat`, `armorruins`.
- Portable and advanced equipment: `portablecookpot_item`, `portableblender_item`, `portablespicer_item`, `glasscutter`, `archive_resonator_item`, `moondial`, `moonrockcrater`, `moonglassaxe`.

The existing ingredient tables, recipe images, builder tags and other metadata are preserved. The station migration does not call `AddRecipe2` to recreate a recipe. A guarded post-init pass and a bounded world-task retry reapply the station filter after other mods' initialization.

`researchlab`, `researchlab2` and `transistor` remain in the science progression. Moving the components required to build the War Bench itself would create a crafting dependency loop. The rare ingredients of ruins/lunar recipes continue to gate their progression even though the War Bench supplies the metalworking technology.

Existing MAM weapons/equipment continue to use their individual War Bench recipes. The Crafting Book remains a separate prototyper; non-metal clothing recipes are not moved as a side effect.

## 2. Read-only Metallurgy Guide

Prefab: `metallurgy_reference_book`  
Recipe: 2 papyrus + 2 charcoal + 1 iron ingot at `TECH.ALCHEMY_ONE`.

The item uses DST's `simplebook` action and opens a client-side popup screen. It is a read-only guide, not a prototyper and not a recipe unlock. Pages are generated from the active `smelting_products` table and cover:

1. Overview and batch/ingredient-tag rules.
2. Metal conversion chain and alloys.
3. Mining and drop sources.
4. War Bench crafting progression.
5. Deconstruction and character recovery rates.
6. W.O.B.O.T./W.I.N.bot automation.
7. Compatibility and safety.
8. All registered smelting products, paginated with base time and ingredient tags.

Page labels and explanatory text are bilingual English/Portuguese. Product names use the game's active localized strings.

## 3. Deconstruction and salvage

Action: `MAM_DECONSTRUCT_METAL`, right-click on a supported item while within 8 units of the War Bench. The server validates station proximity, item ownership, recipe eligibility and output capacity before consuming one item.

### Material chain returns

| Input | Canonical components |
|---|---|
| Copper ore | 2 copper dust |
| Copper ingot | 3 copper ore |
| Iron ore | 2 iron dust |
| Iron ingot | 3 iron ore |
| Gold nugget | 2 gold dust |
| Gold ingot | 3 gold nuggets |
| Bronze ingot | 3 copper ore + 1 iron ore |
| Moonglass ingot | 2 moonglass + 1 moonrock nugget |
| Adamantium ingot | 3 nightmare fuel + 1 iron ingot |

These mappings mirror the corresponding smelting ingredient composition. The return is always to a lower material stage; the smelter remains the route upward.

### Crafted equipment

Only the explicit metal/War Bench allowlist is eligible. The action reads the live `AllRecipes[prefab].ingredients` and `numtogive`, preserving recipe changes made by other mods. It does not copy a stale cost list. Recipe entries marked `no_deconstruction` are refused.

### Recovery

- Standard: 75% expected return per ingredient unit, using an independent recovery roll.
- Wilson: 100% for all listed components.
- Winona: 100% for non-magical metal components; other recipe ingredients use the standard rate.
- Maxwell: 100% for shadow components; other recipe ingredients use the standard rate.
- WX-78 and Wickerbottom: standard rate until a specific specialty is approved.
- Equipment salvage is multiplied by remaining finite-use/armor durability. A fully depleted item has no remaining salvage.
- Output capacity is checked before input removal. A no-return roll still consumes the item, so players cannot retry the same item until a favorable roll.

Wilson's separate cross-material transmutation is not implemented in this build: no conversion matrix or ratios were specified. Wilson's 100% exact ingredient recovery is implemented; transmutation remains a distinct design task, not an assumed free conversion.

## 4. Collector robot automation

Configuration: `mam_robot_smelting`, default Off.

When enabled, the smelter checks every five seconds for a fueled active `storagerobot` within eight world units:
- W.O.B.O.T.: fueled, deployed in the world, not broken/held.
- W.I.N.bot: fueled, deployed and active.

The smelter scans nearby compatible chest/pack containers on the same platform, excluding portable storage and player inventories. It considers only items registered as smelting ingredients. The existing batch planner chooses the product and exact consumed quantities; the smelter stages only those quantities and passes the original plan into the normal transaction path, avoiding a second random product roll.

When ready, the output is deposited into the nearest compatible container that can accept the complete remaining batch. If no container has enough room, the output stays ready in the smelter for manual collection. The automation never scans or drains player inventories.

## 5. Dedicated metal chest retirement

The dedicated metal chest recipe and configuration option are removed. The prefab/widget remain registered solely to keep existing saves with the old chest loadable. New worlds cannot craft the dedicated chest. Robot automation uses compatible existing containers instead.

## 6. Icon build

- Source: `images/branding/metals_and_more_reforged_icon.svg`. CI rasterizes it to a 256px PNG with `rsvg-convert` before packaging.
- CI checks out the pinned KTools `ktech` source commit `a1d1362bdb2b9aa9146d7177fbf0e351eab414ba`, builds the open-source converter, and generates `modicon.tex`.
- `modicon.xml` maps the full square texture.
- The generated KTEX is included in the install ZIP; the source PNG/SVG remain for reproducibility.

## 7. Outstanding items

- Wilson's separate cross-material transmutation requires an explicit conversion matrix and balance approval.
- WX-78/Wickerbottom recovery specialties remain unassigned.
- In-game verification is still required for the new book screen, station visibility, salvage inventory transaction, W.O.B.O.T./W.I.N.bot behavior, save/load and multiplayer.
- The full user mod collection and UM Public Beta 6.0.3.9 require one consolidated local test.
