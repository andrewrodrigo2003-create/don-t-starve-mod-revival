# Forecast certainty-only mode: ambiguous-load regression test

## Regression

When `mam_forecast = 1`, the planner intentionally returns an `ambiguous` state if multiple highest-priority recipes match. The UI displays `Mixed load`, but the previous `can_start` implementation accepted only `ready` plans with a single product. That unintentionally disabled the Smelt action for valid mixed loads, even though the server's original weighted recipe selection can resolve the result when smelting starts.

The fix permits starting only the explicit ambiguity state produced by certainty-only mode, with more than one candidate. Invalid loads and other ambiguous/error states remain blocked.

## Run

```sh
texlua dst-mods/tests/forecast_ambiguous_start_test.lua
```

## Test boundary

The test loads the real `smelting.lua` and `mam/forecast.lua`. It stubs only configuration, structured logging, and the DST container replica/item objects. It does not load the DST engine and does not replace the forecast or recipe-selection logic.
