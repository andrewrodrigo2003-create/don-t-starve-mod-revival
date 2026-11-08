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
