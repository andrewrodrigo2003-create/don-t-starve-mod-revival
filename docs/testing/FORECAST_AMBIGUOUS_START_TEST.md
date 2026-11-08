# Smelter forecast: ambiguous loads and replicated stack sizes

## Regressions covered

1. When `mam_forecast = 1`, the planner intentionally returns an `ambiguous` state if multiple highest-priority recipes match. The UI displays `Mixed load`, but the previous `can_start` implementation accepted only `ready` plans with a single product. That unintentionally disabled the Smelt action for valid mixed loads, even though the server's original weighted recipe selection can resolve the result when smelting starts.
2. The forecast reads the container through the client replica, but it previously read `item.components.stackable`. Stack sizes are synchronized to clients through `item.replica.stackable`; consequently a client could treat a stack of ore as one item and forecast the wrong batch quantity.

## Fixes

- Permit starting only the explicit ambiguity state produced by certainty-only mode, with more than one candidate. Invalid loads and other ambiguous/error states remain blocked.
- Use generic "result" wording for ambiguous mixtures because candidate recipes are not necessarily alloys.
- Read stack size from `item.replica.stackable` when available, with a server-component fallback for server-side callers.

## Run

```sh
texlua dst-mods/tests/forecast_ambiguous_start_test.lua
```

## Latest verification

GitHub Actions run #19 passed on the current PR head with Lua 5.1:
- All Lua files under `dst-mods/metals_and_reforged` passed syntax parsing.
- The forecast regression harness reported **14 passed; 0 failed**.

Run: https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/actions/runs/42444697946

## Test boundary

The test loads the real `smelting.lua` and `mam/forecast.lua`. It stubs only configuration, structured logging, and DST-facing container/item objects. It covers certainty-only behavior, invalid loads, a six-item copper stack represented only through the client replica, tied recipes with different per-unit costs and cook times, and safe consumption for a legacy third-party recipe without cost metadata.

It does not load the DST engine or validate actual network delivery, container UI events, or live multiplayer. Those remain in-game checks.
