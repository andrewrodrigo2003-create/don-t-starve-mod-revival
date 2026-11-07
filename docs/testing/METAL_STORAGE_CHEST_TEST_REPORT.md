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
  - the item filter delegates to the exported `smelting.IsSmelterIngredient(item.prefab)` predicate;
  - the prefab uses the master-simulation guard before adding server components;
  - the container calls `DropEverything()` before the structure is removed.
- LuaTeX parsed `metal_storage_chest.lua` successfully.
- A stubbed LuaTeX behavior harness executed the prefab factory and checked:
  - expected prefab name;
  - expected container widget setup;
  - three hammer work units;
  - ordinary hit closes the container without spilling contents;
  - hammer destruction returns the container contents and removes the structure.

## Not tested

- Full `modmain.lua` or `modinfo.lua` loading inside DST.
- Real asset resolution or visual/UI alignment in the game.
- Actual item acceptance for every smelting ingredient in a running game.
- Save/reload, snow coverage, haunt behavior, server/client replication, multiplayer, or Uncompromising Mode Beta.
- Crafting balance and placement in the user's world.

## Important design boundary

The filter intentionally accepts items registered by the smelting ingredient table. It does not yet implement nearby-container aggregation, withdrawal, station access, or external-container integration. Those are separate milestones and must be server-authoritative, distance-limited, permission-aware, and tested against duplication/loss before being enabled.
