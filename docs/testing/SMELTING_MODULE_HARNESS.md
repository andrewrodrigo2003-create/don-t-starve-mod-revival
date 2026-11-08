# Metals and More Reforged — real smelting-module harness

## Purpose

This harness exercises the repository's actual `scripts/smelting.lua` together with its actual `scripts/smelting_products.lua`. It replaces only the engine-facing `tuning` import and the server configuration module with minimal stubs. It is not a behavioral reimplementation of the batch algorithm.

Run from the repository root:

```sh
texlua dst-mods/tests/smelting_module_harness.lua
```

A Lua 5.1-compatible interpreter can also run it:

```sh
lua dst-mods/tests/smelting_module_harness.lua
```

## Coverage

- Empty and unrecognized loads do not produce output.
- Copper batch count, exact consumption, and leftovers.
- Configured batch cap and batch-disabled behavior.
- Bronze's combined copper/iron requirements.
- Moonglass's glass/moon requirements.
- Gold's two-tag requirement.
- All seven gem recipes: red, blue, purple, green, yellow, orange, and opal, using minimal valid shard combinations; red-gem multi-batch output is also covered.
- Adamantium's named iron-ingot prerequisite and intrinsic five-unit cap.
- Nitre's ordinary mineral route batches by mineral cost; its gem-fragment fallback consumes the fragments used while preserving unrelated items.
- Junk dust consumes its half-unit metal input and remains capped at one output.
- Ore pass-through remains capped at one output.
- Forecast is deterministic for a single candidate, does not mutate inputs, and honors server-published batch/cap/time settings.

## Test boundary

The harness directly invokes the real recipe and planning functions. The assertion count includes each per-prefab consumption and leftover check performed by the shared helper. The `tuning` and `mam/config` modules are stubbed; no DST globals, prefab, container component, inventory, netvar, UI widget, save system, or multiplayer server/client is loaded.

A passing harness therefore verifies the Lua module's planning/forecast logic under these controlled inputs. It does **not** prove the full mod loads in DST or validate item spawning, container APIs, interruption behavior, save/reload, UI events, or multiplayer replication. Those remain separate engine/in-game checks.

## Expected result

The harness contains 80 assertions across the cases above. The script prints one `PASS`/`FAIL` line per assertion and exits nonzero if any assertion fails. Record the exact interpreter and output in the PR review when run in the repository checkout.
