# DST Lifecycle and Task Ownership Audit — Metals and More Reforged

**Date:** 2026-11-10  
**Status:** Static source audit; no gameplay code changed  
**Branch:** `engineering/forensics-testing-toolkit-2026-11-09` (MAM PR #25, draft/open)  
**Scope:** Entity tasks, component task ownership, event listeners, sleep/wake behavior, UI listener cleanup and smelter update scheduling.

## Executive summary

The audit found one high-confidence dead lifecycle branch, one recurring idle-work candidate, and one cross-mod task-ownership hazard. It also found a good cleanup pattern in the forecast UI. These are source-level findings only: no L4 DST runtime, save/reload, Uncompromising Mode Beta or multiplayer test was run.

## Findings

### 1. Bernie Big: sleep-to-inactive task branch appears unreachable

**File:** `scripts/prefabs/bernie_big.lua`  
**Evidence:** `OnEntitySleep` lines 134–138 checks `inst._sleeptask ~= nil` before assigning a new task. In this prefab file, no initialization or other assignment to `_sleeptask` exists before that check; `OnSleepTask` only clears it (line 130). `OnEntityWake` cancels and clears it (lines 140–145).

**Interpretation:** Unless another integration writes this private field on the Bernie entity, the sleep callback never schedules `OnSleepTask`, so the apparent sleep-to-`GoInactive` path is dormant. This may be an old intended behavior or a deliberate disable; confirm design intent before changing it.

**Priority:** Medium; confidence high for the local control-flow observation, runtime/design intent unconfirmed.

**Verification:** In a disposable world, observe Bernie Big entering sleep, waking before the delay, and remaining asleep. Record whether it should transform to `bernie_inactive`; inspect exact installed prefab source and other mod hooks for writes to `_sleeptask`.

### 2. Bernie Big: generic `target.task` property can collide with other mods

**File:** `scripts/prefabs/bernie_big.lua`  
**Evidence:** `OnHitOther` (lines 98–117) cancels `data.target.task`, writes a new delayed task to that same generic property, then the callback reads `data.target.components.health` and clears the property.

**Interpretation:** The MAM code claims a generic field on an entity it does not own. If another mod or prefab uses `target.task` for unrelated work, MAM may cancel it or overwrite its reference. The callback also assumes the target still has a health component when it runs. Entity-bound tasks are normally cancelled when their owning entity is removed, but component removal or other mod mutation still deserves a defensive check.

**Priority:** Medium; confidence high that the shared field is used, collision is conditional and not proven in a live mod stack.

**Recommended direction:** Store the task under a namespaced MAM field or, preferably, own the task on the Bernie instance keyed by target GUID; cancel only tasks MAM created. In the callback, validate target existence and health before use. Add tests for repeated hits, two Bernies hitting one target, target removal, component removal, and a foreign mod-owned `task` field. Do not patch until intended stacking behavior is decided.

### 3. Smelter component: periodic update is scheduled even while idle

**File:** `scripts/components/smelter.lua`  
**Evidence:** The component constructor calls `self:Update(0)` (line 32). At the end of every `Update`, if `self.task == nil`, it schedules `self.inst:DoPeriodicTask(0.5, OnDoUpdate, nil, self, 0.5)` (lines 329–346). The scheduling condition does not check `self.issmelting` or `self.canharvest`. No `OnRemoveFromEntity` cleanup method is defined in this component.

**Interpretation:** Each smelter starts a half-second periodic task during construction, including when idle. The callback continues to call `Update`; in idle state the smelting branch does no work, but the scheduled callback still wakes up and executes. Entity removal is handled by the engine's entity-task cleanup; the concern here is unnecessary recurring work while the machine exists, not a proven task leak after entity removal.

**Priority:** Medium performance opportunity; confidence high for the source path, actual scheduler cost and sleep behavior need runtime measurement.

**Recommended direction:** Consider scheduling only when smelting begins/resumes, then cancelling and clearing the task when the machine becomes harvest-ready or resets. If a periodic task is retained, define explicit component-removal cleanup and idempotent start/stop helpers. Preserve save/load edge cases where `OnLoad` defers completion until the container is restored.

**Required regression cases:** idle smelter creates no recurring update; start/resume creates exactly one task; repeated start does not duplicate it; completion/reset cancels it; save with positive time resumes once; save with zero/missing time completes once after container restoration; entity/component removal leaves no active work.

### 4. Forecast UI: listener cleanup is implemented correctly

**File:** `initialise/modded_ui_forecast.lua`  
**Evidence:** Widget setup stores `self.mam_plan_listener` and registers it on the container (around lines 60–70). The wrapped `ContainerWidget:Close(...)` removes that exact listener from a still-valid container, then clears the listener and cached text fields (around lines 97–101).

**Interpretation:** This is a good ownership pattern: the widget remembers the listener it registered and removes it on close. Preserve this behavior when changing the forecast UI. Add a UI lifecycle test for repeated open/close, container replacement/removal, and close after the source entity becomes invalid.

### 5. Smelter prefab client setup: delayed callback is guarded

**File:** `scripts/prefabs/metal_smelter.lua`  
**Evidence:** Client-side `mamplandirty` listener updates the widget setup. A zero-delay task checks `inst:IsValid()`, `inst.replica`, and `inst.replica.container` before calling `WidgetSetup` (around lines 248–255).

**Interpretation:** The callback checks the entity and replica before use. The listener is attached to the entity itself, so entity teardown owns its lifetime. Keep this guard if the setup timing is changed.

## Cross-check with public DST lifecycle references

- `EntityScript:Remove()` is documented as stopping entity tasks and cleaning entity listeners/components during removal: https://vietnd69.github.io/dst-api-webdocs/docs/game-scripts/entityscript
- `OnEntitySleep` / `OnEntityWake` push sleep/wake lifecycle events and hibernate/wake entity systems: https://vietnd69.github.io/dst-api-webdocs/docs/game-scripts/mainfunctions
- `AddPrefabPostInit` runs for a spawned prefab and is called on server and client: https://vietnd69.github.io/dst-api-webdocs/docs/game-scripts/modutil
- Example of explicit sleep-task cancellation on wake and component removal: https://vietnd69.github.io/dst-api-webdocs/docs/game-scripts/components/vanish_on_sleep

These references are public documentation/source profiles, not proof of the exact behavior of the user's installed game build. The MAM branch source was read directly from GitHub; the user's installed `scripts.zip` was not available in this audit.

## L4 test plan (not yet run)

1. Bernie Big sleep/wake: verify whether sleep-to-inactive is intended and whether the current condition ever schedules.
2. Bernie target debuff: repeated hits, multiple Bernies, target despawn, health-component removal, and collision with a foreign `target.task` value.
3. Smelter idle soak: instrument callback count over a fixed interval with several idle smelters; compare current periodic scheduling against an event-driven prototype in a disposable branch/world.
4. Smelter transitions: start, resume, completion, harvest, reset, save/reload with positive and zero remaining time, then entity removal.
5. Forecast widget: repeated open/close and container destruction while open; ensure listener count returns to baseline.
6. Repeat with Uncompromising Mode Beta and the user's ordinary mod stack only after baseline cases pass.

## Recommended order

1. Decide whether Bernie Big's sleep-to-inactive behavior is intended; fix only if confirmed.
2. Replace the generic `target.task` ownership with a namespaced, MAM-owned task lifecycle.
3. Prototype event-driven smelter task start/stop and measure it before adopting.
4. Preserve forecast UI listener cleanup and add lifecycle regression tests.

## Evidence boundary

This report is a static code review. It does not claim the mod was launched, the game world was run, a benchmark was performed, or multiplayer/UM Beta compatibility was validated. No gameplay code, damage values, recipes, or balance were changed.
