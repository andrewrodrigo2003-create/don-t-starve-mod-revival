# Legacy smelter recipe default weight

## Defect

The legacy exported `CalculateSmelterRecipe` function already treated an omitted recipe weight as `1` when sorting candidates and calculating the total weight, but subtracted the raw `weight` field during the weighted roll. A third-party recipe that omitted `weight` therefore passed candidate selection and then failed with an arithmetic error.

## Fix

Use the same `weight or 1` fallback in the subtraction step. This preserves the established default and does not change recipes that declare a weight.

## Regression test

`dst-mods/tests/legacy_recipe_default_weight_test.lua` registers a highest-priority external recipe without a weight, invokes the exported legacy function, and checks its result and cook time.

Run from the repository root:

```sh
lua5.1 dst-mods/tests/legacy_recipe_default_weight_test.lua
```

The workflow runs this regression alongside the existing Lua syntax checks and smelter harnesses.

## Verification boundary

This test loads the real smelting module with only the DST tuning and configuration imports stubbed. It does not load the DST engine, container widget, save system, multiplayer transport, or a live third-party mod.
