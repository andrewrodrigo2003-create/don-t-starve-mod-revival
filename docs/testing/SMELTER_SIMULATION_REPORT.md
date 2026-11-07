# Metals and More Reforged — Smelter Simulation Report

Date: 2026-11-07
Branch: `fix/nitre-gem-fallback-consumption`
Pull request: #1 (draft; not merged)

## Scope

Reviewed the current branch versions of:
- `scripts/smelting.lua`
- `scripts/smelting_products.lua`
- `scripts/components/smelter.lua`
- `scripts/prefabs/metal_smelter.lua`
- `scripts/mam/forecast.lua`

No files belonging to other mods were changed.

## Tests executed

A Lua behavioral model was run with the locally available LuaTeX interpreter (`texlua --luaonly`). It mirrors the relevant batch-count, consumption-planning, and hammer-drop logic. It is a model of the source logic, not the DST engine and not a direct execution of the mod modules.

| Scenario | Result |
|---|---|
| Copper: 10 ore, 3 copper per ingot | PASS — 3 ingots, 9 ore consumed, 1 left |
| Bronze: 6 copper + 2 iron ore | PASS — 2 ingots, all required inputs consumed |
| Moonglass: 6 glass + 2 moonrock nuggets | PASS — 2 ingots, 4 glass + 2 moonrock consumed, 2 glass left |
| Nitre gem-fragment fallback | PASS — gem fragments consumed; unrelated twigs preserved |
| Adamantium named prerequisite | PASS — steel input and iron ingot prerequisite both consumed for 2 outputs |
| Hammer ready furnace: stackable output batches 1, 20, 21, 40, 45 | PASS — entire batch dropped, split into stacks of at most 20 |
| Hammer ready furnace: non-stackable batch of 3 | PASS in the behavioral model — 3 individual drops |

Static source checks also passed for the new hammer-drop loop, its decrement logic, stack splitting, and dropping container leftovers before removing the furnace.

## Additional lifecycle review

The component's save/load code contains fields and paths for saving an active smelt (product, batch, remaining time, active flag) and restoring it with `ResumeSmelting()`. It also restores the ready-to-harvest state without calling `DoneSmelting()`, avoiding destruction of container contents during load. These paths were inspected statically, not run inside DST.

### Needs in-game verification / design decision

Inputs are consumed at `StartSmelting()`. The current hit/interruption path calls `ResetSmelter()`, which can only drop items still in the container; it does not have a saved snapshot of already-consumed inputs. Therefore, hitting the furnace during an active smelt appears to cancel the operation after the batch inputs have already been consumed. Hammering the furnace while smelting also removes it before an output is ready. This may be intentional risk/punishment, but it must be confirmed in-game before changing the behavior.

## Not tested

- Direct Lua syntax/runtime loading of the complete mod files against DST globals.
- Actual Don't Starve Together simulation, animation, prefab spawning, inventory insertion, container APIs, or world save/reload.
- Multiplayer replication and client/server timing.
- Uncompromising Mode Beta compatibility.
- Destruction/interruption behavior in a live world.

No GitHub Actions workflow run was found for the tested commit. A local LuaTeX interpreter was available, but a DST-compatible Lua runtime and game engine were not.

## Next in-game test checklist

1. Smelt copper, iron, bronze, gold, moonglass, gems, nitre, and adamantium with exact and excess inputs.
2. Check that leftovers are returned when enabled and destroyed only when the original-behavior option is selected.
3. Save/reload during an active smelt and while ready to harvest.
4. Hit and hammer the furnace during an active smelt; record whether consumed inputs should be lost or refunded.
5. Hammer a ready furnace with output batches above 20 and with a non-stackable product.
6. Repeat in multiplayer and with Uncompromising Mode Beta enabled.

The PR remains draft and unmerged pending review and in-game validation.
