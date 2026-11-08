# Integrated Metals and More smelter validation

## Scope

This temporary validation branch combines the current draft work from PRs #3, #9, #10, and #11 without merging any of them into `main`.

It covers:
- the real `smelting.lua` and `smelting_products.lua` batch/consumption planner;
- client-side forecast behavior, ambiguous recipes, replicated stack sizes, and server configuration;
- the real smelter component's start, consumption, interruption, and save/load lifecycle;
- the server-published `mam_plan` config string flowing into the client stack-acceptance helper;
- the client widget's fallback and refresh behavior when replicated configuration arrives late.

## Latest verification

GitHub Actions run **#42445185933** completed successfully on commit `520d640b5276b976a60a47b9817175778bcb8707`:

| Harness | Assertions |
|---|---:|
| Recipe module and batch planner | 81 passed, 0 failed |
| Forecast and ambiguous start | 14 passed, 0 failed |
| Smelter lifecycle + component/config handshake | 24 passed, 0 failed |
| Server/client stack settings | 16 passed, 0 failed |
| **Total** | **135 passed, 0 failed** |

All Lua files under `dst-mods/metals_and_reforged` also passed Lua 5.1 syntax parsing.

Run: https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/actions/runs/42445185933

## Limits

This is a Lua 5.1 integration harness with controlled DST-facing stubs. It does not execute the DST engine and does not prove real network timing, container replica creation order, save serialization, world reload, multiplayer behavior, or compatibility with Uncompromising Mode Beta. Those checks remain pending in the in-game test world.

No PR was merged and no production branch was changed by this validation snapshot.
