# Metal Storage Chest — test report

Date: 2026-11-07  
Branch: `feature/metal-storage-chest`  
Pull request: #5 (draft; not merged)

## Scope

New `metal_storage_chest` prefab, 25-slot widget, smelter-ingredient filter, recipe, configuration option, and destruction behavior.

## Checks performed

- Static source checks confirmed:
  - prefab is registered in `PrefabFiles`;
  - the recipe is gated by `MAMConfig.on("mam_metalschest")`;
  - the setting exists in `modinfo.lua` and its default exists in `mam/config.lua`;
  - the container widget is registered as `metal_storage_chest`;
  - the prefab has both the generic `chest` tag and the mod-specific `mam_metal_storage` tag for container-discovery integrations;
  - the item filter delegates to the exported `smelting.IsSmelterIngredient(item.prefab)` predicate;
  - the prefab uses the master-simulation guard before adding server components;
  - the container calls `DropEverything()` before the structure is removed.
- The current source was inspected statically. Registration, filter, server-only components, widget setup, hit behavior and destruction path were checked by reading the code.
- Added `dst-mods/tests/metal_storage_chest_test.lua`, an isolated prefab harness that loads the real prefab file with stubs for DST APIs.
- Ran the harness with `texlua --luaonly`; it passed checks for prefab registration, assets, placer, generic/custom tags, widget binding, callbacks, ordinary-hit close-without-spill behavior, hammer destruction spilling stored contents, and server/client component separation.
- The harness is not the DST engine. It does not verify the actual container component, network replication, item acceptance against every registered ingredient, save/load, assets, or multiplayer.

## Not tested

- Full DST Lua/API loading; the isolated prefab harness passed but does not load the full mod.
- Full `modmain.lua` or `modinfo.lua` loading inside DST.
- Real asset resolution or visual/UI alignment in the game.
- Actual item acceptance for every smelting ingredient in a running game.
- Save/reload, snow coverage, haunt behavior, server/client replication, multiplayer, or Uncompromising Mode Beta.
- Crafting balance and placement in the user's world.

## Important design boundary

The filter intentionally accepts items registered by the smelting ingredient table. It does not yet implement nearby-container aggregation, withdrawal, station access, or external-container integration. Those are separate milestones and must be server-authoritative, distance-limited, permission-aware, and tested against duplication/loss before being enabled.
