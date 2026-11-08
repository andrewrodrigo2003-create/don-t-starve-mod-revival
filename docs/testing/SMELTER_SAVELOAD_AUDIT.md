# Smelter interruption and save/load audit

Date: 2026-11-07  
Branch: `fix/smelter-interruption-leftovers`  
Pull request: #3 (draft; not merged)

## Changes in this branch

1. `ResetSmelter()` now applies the leftovers option on interruption:
   - enabled: return remaining container items with `DropEverything()`;
   - disabled: destroy remaining contents with `DestroyContents()`, matching the original completion behavior.
2. Save/load restoration now gives the ready-to-harvest state precedence over a stale `issmelting` flag.
3. Missing or invalid saved `smelttime` is normalized to zero instead of being assigned as nil and later subtracted during `Update()`.
4. A smelt saved at exactly zero/expired time is completed on a zero-delay task after entity load callbacks, rather than being left stuck or completing inline before container restoration.
5. A saved active smelt with no saved product is reset safely instead of remaining stuck with an invalid state.

## Verification performed

- Static source checks passed for both branches of the leftovers setting, nil-safe time normalization, ready-state precedence, deferred completion, and skipping immediate `Update(0)` while completion is deferred.
- LuaTeX harness executed six isolated OnLoad state cases:
  1. active smelt with positive remaining time resumes;
  2. zero remaining time defers completion and then becomes harvestable;
  3. missing remaining time is normalized and completes safely;
  4. negative remaining time is clamped and completes safely;
  5. ready-to-harvest takes precedence over a stale active flag;
  6. active save with missing product resets safely.

The harness reproduces the relevant state-transition logic with stubs; it does not load the full component or DST APIs.

## Not tested

- Actual DST component load ordering and container restoration in a running game.
- In-game interruption, save/reload, multiplayer, or Uncompromising Mode Beta.
- Real inventory delivery and visual/animation behavior after a loaded completion.

These remain required in-game checks in the user's test world, `mundo de testes de mod`.


## Direct component lifecycle harness

Added `dst-mods/tests/smelter_component_lifecycle_test.lua`, which loads the actual `scripts/components/smelter.lua` component and stubs only the smelting planner, config/log modules, and DST entity/container APIs.

The harness contains 22 assertions for:
- exact partial-stack consumption and full-stack removal when a real component `StartSmelting` call applies a supplied plan;
- rejecting invalid plans without consuming inputs or locking the container;
- both leftovers settings during interruption;
- resuming positive-time saves;
- deferring zero-time completion until after a simulated container restore callback;
- ready-to-harvest precedence and safe reset when a saved active smelt has no product.

Run from the repository root:

```sh
texlua dst-mods/tests/smelter_component_lifecycle_test.lua
```

The new harness has been reviewed statically but has **not yet been executed** in this environment. Its simulated deferred callback does not prove the actual DST save/load callback order. In-game save/reload and multiplayer checks remain mandatory.
