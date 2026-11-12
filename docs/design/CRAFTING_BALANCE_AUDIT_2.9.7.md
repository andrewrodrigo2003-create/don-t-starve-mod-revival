# Crafting and progression balance audit — Metals and More Reforged 2.9.7

Date: 2026-11-12  
Status: source inventory and balance hypotheses; no recipe cost is approved solely by this document.

## Design target

Metals and More should create a perceptible alternative crafting progression built around mining, smelting, alloys, dedicated stations and metal equipment. It must not become a blanket metal tax on every vanilla recipe. Vanilla routes remain viable where they do not conflict with a deliberate MAM replacement.

Every proposed change must be evaluated across:
- **Acquisition:** renewable/finite source, biome, risk, expected quantity and access tier.
- **Processing:** smelter/station, fuel, time, tool, recipe tier and conversion loss.
- **Usage pressure:** how often the material is consumed, progression importance, repairs and competing recipes.

For each recipe, record the vanilla baseline, MAM proposal, delta in raw material value, time/fuel, station tier, and impact on time-to-progression. Test the complete chain, not isolated ingredient counts.

## Current recipe inventory from source

The current values below are read from `initialise/modded_recipes.lua` and `modmain.lua` on the 2.9.7 branch. They are the existing proposal, not newly approved balance decisions.

| Recipe | Vanilla baseline | Current MAM proposal | Audit focus |
|---|---|---|---|
| Science Machine | 1 gold nugget, 4 logs, 4 rocks | 4 iron ore, 4 logs, 4 rocks | Early-game access to iron; ensure no circular dependency and measure time to first science tier |
| Alchemy Engine | 4 boards, 2 cut stone, 2 transistors | 4 boards, 2 iron ingots, 2 transistors | Iron ore demand and smelting time before tier 2 |
| Birdcage | 2 papyrus, 6 gold nuggets, 2 seeds | 2 papyrus, 1 bronze ingot, 2 seeds | Bronze alloy access vs vanilla gold cost |
| Dragonfly Chest | 1 dragon scale, 4 boards, 10 gold nuggets | 1 dragon scale, 4 boards, 2 gold ingots | Gold conversion cost and post-boss utility |
| Compass | 1 gold nugget, 1 flint | 1 iron ore, 1 flint | Early exploration access; raw ore should not become a bottleneck |
| Razor | 2 twigs, 2 flint | 2 twigs, 1 iron ingot | One ingot represents 3 iron-value units in the current smelting table |
| Transistor | 2 gold nuggets, 1 cut stone | 1 copper ingot, 1 cut stone | Copper availability and science progression |
| Lightning Rod | 4 gold nuggets, 1 cut stone | 1 gold ingot, 1 cut stone | Gold ingot currently represents 3 gold-value units |
| Golden Axe/Pickaxe/Shovel/Farm Hoe | 4 twigs, 2 gold nuggets | 4 twigs, 1 gold ingot | The current ingot route raises nominal gold value from 2 to 3 units; assess against durability and tool tier |
| Marble Armor | 6 marble, 2 rope | 12 marble, 4 rope, 1 iron ingot | Current proposal doubles marble/rope and adds iron; check defense, durability and acquisition risk |
| Portable Cookpot | 2 gold nuggets, 6 charcoal, 6 twigs | 3 iron ore, 6 charcoal, 6 twigs | Compare raw iron acquisition to gold baseline and portable cooking utility |
| Portable Blender | 2 gold nuggets, 2 transistors, 4 twigs | 3 iron ore, 2 transistors, 4 twigs | Avoid charging both the full iron route and the existing transistor gate without clear value |
| Portable Spice Station | 2 gold nuggets, 3 cut stone, 6 twigs | 3 iron ore, 3 cut stone, 6 twigs | Compare material access and the value of portable seasoning |
| Glass Cutter | 1 log, 5 moonglass | 1 board, 1 moonglass ingot | Verify moonglass-ingot conversion yield and lunar progression timing |
| Archive Resonator | 1 moonrock nugget, 1 Thulecite | 2 moonglass ingots, 1 Thulecite | Check lunar material conversion and whether the extra ingot cost is intentional |
| Moon Dial | 1 blue moon eye, 2 moonrock nuggets, 2 ice | 1 blue moon eye, 1 moonglass ingot, 5 marble | Verify material availability in lunar progression; marble should have a clear design reason |
| Moonrock Crater | 3 moonrock nuggets | 1 moonglass ingot, 2 moonrock nuggets, 1 marble | Added processed material and marble; compare against the crater's utility |
| Moonglass Axe | 2 twigs, 3 moonglass | 2 twigs, 1 moonglass ingot, 1 marble | Compare ingot conversion yield and tool durability |
| Metal Smelter | MAM-owned | 4 iron ore, 2 cut stone | Validate earliest access and no softlock |
| War Workbench | MAM-owned | 5 cut stone, 3 iron ingots, 5 charcoal | High-impact progression gate; compare output recipes and station role |
| Marble Chest | MAM-owned | 5 marble, 2 gold ingots, 3 cut stone | Verify real slot count, fire behavior, hammer returns and cost against vanilla chest |
| Cold Safe (fridge) | MAM-owned | 1 gear, 3 iron ingots, 1 blue gem | Verify real slot count, food preservation multiplier and cost against vanilla icebox |

## Confirmed conversion facts from the current smelting code

- One `iron_ingot` requires at least 3 iron-value units and has a 15-second base cook time.
- One `copper_ingot` requires at least 3 copper-value units and has a 15-second base cook time.
- One `gold_ingot` requires at least 3 gold-value units plus the current metal-tag threshold and has a 15-second base cook time.
- One `bronze_ingot` requires at least 3 copper-value units plus at least 1 iron-value unit.
- One `moonglass_ingot` requires at least 2 moonglass-value units and moon-tag value.
- These are minimum recipe predicates; the actual load may contain more material, competing candidate recipes, fuel and batch time. Do not equate one ingot with one nugget.

## Required storage audit

The mod already has:
- `marble_chest`: uses the 5×5 chest animation asset and calls `WidgetSetup("marble_chest")`.
- `cold_safe`: uses the 5×5 chest animation asset, has the `fridge` tag and calls `WidgetSetup("cold_safe")`.
- `metal_storage_chest`: legacy prefab kept for save compatibility; no new crafting recipe should be added.

Before changing either existing recipe, resolve the actual registered container widget layouts and food-preservation behavior in the active DST build. The animation asset alone does not prove the slot count. Compare the real capacity and functionality to the vanilla chest/icebox. The marble chest and cold safe must be priced according to their actual delivered utility, not their names or art.

## Priority balance decisions

1. **Early progression:** ensure the smelter can be reached reliably and that the Science Machine / Alchemy Engine changes do not create excessive early iron scarcity.
2. **Core utility recipes:** compass, razor, transistor, lightning rod and golden tools should make metalworking visible without making routine survival utilities disproportionately expensive.
3. **Portable cooking:** review all three portable stations together; avoid stacking metal and transistor costs without a meaningful progression benefit.
4. **Marble armor and storage:** compare material costs to defense, durability, capacity and preservation utility.
5. **Lunar/ruins recipes:** compare ingot conversion cost against actual lunar material yield and unlock timing.
6. **MAM stations/equipment:** validate the combined cost of the smelter, warworkbench, metal tools and weapon/armor recipes as a progression chain.

## Release tests

- Cost-contract tests for every changed recipe, including the baseline and expected MAM signature.
- Conversion tests using the actual smelting planner, not only tag totals.
- Expected ore acquisition and smelting-time estimates for early, mid and late progression.
- Regression tests with vanilla-only, UM Beta, My Moar Metals and supported optional mods.
- Multiplayer and save/load tests for stations and storage.
- In-game checks in the user's test world before calling any balance decision final.

## Explicit exclusions

- Do not add a new metallurgy chest.
- Do not implement global/nearby storage access or automatic withdrawal in this milestone.
- Do not modify Uncompromising Mode, My Moar Metals, Hydrated/Dehydrated, Better Lucy or other mods.
- Do not apply blanket metal substitutions to every vanilla recipe.
