# Smelter Transaction Integrity Audit — Metals and More Reforged

**Date:** 2026-11-10  
**Status:** Static source audit; documentation only; no gameplay code changed  
**MAM branch:** `engineering/forensics-testing-toolkit-2026-11-09` (PR #25, draft/open)  
**Files reviewed:**
- `scripts/components/smelter.lua`
- `scripts/prefabs/metal_smelter.lua`
- `scripts/smelting.lua`
- `scripts/smelting_products.lua`

## Executive summary

The current smelter has a clear staged flow: calculate a plan, consume the planned ingredient counts, wait, mark the machine harvestable, spawn output, then reset. Save/load preserves product, batch and remaining time. This is a useful foundation, but the flow is not fully transactional: output creation can fail after ingredients have already been consumed, and the machine then clears its saved product entitlement. The component also does not verify that every planned ingredient count was actually consumed before committing to the smelting state.

These are source-level risks. No live DST world, save/reload, Uncompromising Mode Beta, or multiplayer test was run.

## Findings

### 1. Output prefab failure can permanently discard the unspawned remainder

**Files:** `scripts/components/smelter.lua` in `Harvest`; `scripts/prefabs/metal_smelter.lua` in `onhammered`.

Both output loops call `SpawnPrefab(product)`. If it returns nil, the loop logs/prints a warning and breaks. In normal harvest, `Harvest` then calls `ResetSmelter()`, which clears `product` and `batch`. In the hammer-destruction path, the prefab is removed after the loop. Any remaining output quantity therefore has no durable claim and is lost.

**Confidence:** High for the control flow; actual triggering conditions depend on missing/unregistered prefab or runtime spawn failure.

**Recommendation:** Do not clear the output entitlement until all output units have been created and safely transferred. Use a pending-output ledger (product + remaining quantity) and retry or drop a recovery bundle when spawning/inventory delivery fails. Make retries idempotent so they cannot duplicate already delivered units.

### 2. Ingredient consumption is not verified before the operation is committed

**File:** `scripts/components/smelter.lua`, `StartSmelting` and `ConsumeSlot`.

`StartSmelting` calculates a plan from a snapshot of container slots, sets `issmelting`, product, batch and time, calls `startsmeltingfn`, and then iterates the planned `consumed` entries. The return value from `ConsumeSlot(slot, amount)` is ignored. If the slot no longer contains the expected item/count, the helper may consume fewer items (or none), while the machine still proceeds with the full product/batch entitlement.

The normal prefab callback currently changes animation/sound/light rather than editing the container, so this is not evidence of a presently reproducible exploit. It is a contract weakness for future callbacks, integrations, or unusual container mutation.

**Confidence:** High for the missing verification; runtime exploitation is conditional.

**Recommendation:** Validate each planned slot against expected prefab and count, then consume with checked results. If any step fails, roll back all earlier slot changes and restore the machine to idle before publishing/starting. Prefer an explicit transaction helper with a receipt of exact consumed items. Keep side-effecting callbacks after the transaction succeeds.

### 3. Destroying an actively smelting machine has no refund path for already-consumed ingredients

**File:** `scripts/prefabs/metal_smelter.lua`, `onhammered`; `scripts/components/smelter.lua`, `StartSmelting`.

Ingredients are consumed at the beginning of smelting. If the machine is hammered while still smelting, `onhammered` drops the loot table and remaining container contents, but only emits the product when `canharvest` is true. The already-consumed ingredients are not represented in the container and are not refunded.

This may be an intentional destruction penalty; the source alone cannot establish the intended game-design rule.

**Decision required before changing behavior:** choose one explicit policy: (A) destruction forfeits in-progress materials; (B) destruction refunds the exact consumed receipt; or (C) destruction yields a defined partial result. Do not silently change this balance rule.

### 4. Save/load retains the output entitlement, but needs interruption-focused regression coverage

**File:** `scripts/components/smelter.lua`, `OnSave`, `OnLoad`, `ResumeSmelting`.

The save payload stores `canharvest`, `product`, `batch`, `smelttime` and `issmelting`. Loading a ready-to-harvest state restores the ready tag and closes the container. Loading an active state restores the product/batch and resumes the timer; zero or missing remaining time is deferred so the container can restore first.

This is a thoughtful ordering safeguard. It does not by itself guarantee exactly-once output delivery, because harvest is a separate operation and there is no persistent delivery receipt.

**Recommendation:** Preserve the deferred completion ordering. Add tests for saves immediately before completion, exactly at zero time, after completion but before harvest, and after partial output transfer.

### 5. Recipe cost planner has an important compatibility fallback

**File:** `scripts/smelting.lua`, `plan_consumption`.

Recipes without declared `cost` metadata use a conservative fallback: consume all items in the container, preserving the legacy no-free-output behavior. This avoids accidental free production but can surprise third-party recipes that previously expected unused ingredients to remain.

**Recommendation:** Keep the fallback explicit and observable. Log when an external recipe has no cost metadata; document how integrations can declare costs. Do not infer costs from recipe test functions at runtime.

## Proposed transaction invariants

1. **No free output:** every committed output entitlement has a matching, recorded ingredient-consumption receipt or an explicitly approved no-cost recipe.
2. **No silent material loss:** every consumed item is either transformed into a committed output, intentionally forfeited by a documented destruction rule, or returned through rollback/recovery.
3. **Exactly once:** a product unit is either pending, spawned-and-transferred, or recovered; it must never be delivered twice or forgotten.
4. **Atomic start:** the machine enters smelting only after all planned ingredient counts are verified as consumed.
5. **Idempotent recovery:** repeating load/retry/harvest recovery does not duplicate output.
6. **Server authority:** only the authoritative simulation commits consumption and output delivery; UI forecast remains informational.

## L0–L5 test matrix

| Tier | Test | Expected invariant |
|---|---|---|
| L0 static | Verify every product path has cost metadata or explicit fallback | No undocumented free-output path |
| L1 Lua unit | Slot missing, wrong prefab, undersized stack, non-stackable item | Consumption receipt reports exact actual amount |
| L1 Lua unit | SpawnPrefab returns nil on first/middle/final output stack | Remaining output stays pending/recoverable |
| L2 contract | Callback attempts to mutate container before consumption | Start aborts or commits verified receipt; never free batch |
| L2 contract | Repeated harvest/retry | No duplicate delivery |
| L3 simulated | Save/load at active, zero-time, ready, and partial-delivery states | Output entitlement survives exactly once |
| L4 DST runtime | Hammer during smelting and after completion; missing output prefab in disposable test mod | Matches documented destruction/recovery policy |
| L5 mod stack | Repeat with UM Beta and normal mod stack | No duplication/loss; integrations do not bypass authority |

The existing smelting harness results (154/154 from the earlier CI run) are useful regression evidence for the tested planner behavior, but do not establish runtime atomicity, prefab-spawn recovery, real container mutation, or save/reload behavior.

## Recommended implementation order (not performed)

1. Add a pure transaction/receipt helper and unit tests for exact slot consumption.
2. Add pending-output state and failure-safe output delivery; test idempotent retry.
3. Decide the hammer-destruction policy for in-progress batches before implementation.
4. Add L3 save/reload simulation, then validate in disposable DST worlds at L4/L5.
5. Only after these checks, consider performance or UI changes to the forge.

## Evidence boundary

This document records static observations from the MAM branch source. No gameplay code, recipes, costs, output quantities, or balance were modified. No L4/L5 runtime validation was performed.
