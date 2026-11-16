# DST In-Game QA Runner — Design and Operational Contract

**Date:** 2026-11-10  
**Status:** Research/design only; no QA mod implemented yet  
**Goal:** Run deterministic tests inside a real loaded Don't Starve Together world (L4), while keeping the normal MAM release and primary save isolated.

## Why a separate in-game runner

The current CI validates Lua syntax, static contracts, and Lua harnesses. It cannot validate engine behavior such as real component construction, StateGraph execution, client replicas, entity lifecycle, physics, rendering, save/load, or interactions with the user's enabled mod stack.

The proposed runner is a **separate test-only mod**, not code shipped inside Metals and More Reforged. It is enabled only in a disposable QA world and is explicitly invoked by the host/admin. It must not run automatically in ordinary worlds.

## Proposed module layout

```text
dst-mods/
  mam_qa_runner/
    modinfo.lua
    modmain.lua
    scripts/
      mam_qa/
        runner.lua
        report.lua
        scenarios/
          bootstrap.lua
          combat_contracts.lua
          smelter_lifecycle.lua
          containers.lua
          equipment_lifecycle.lua
          cleanup.lua
```

The runner owns only QA fixtures, instrumentation and test commands. It does not patch production gameplay functions except temporarily inside a scenario with guaranteed restoration.

## Invocation and authority

Preferred interface:
- Register explicit host/moderator commands through `AddModUserCommand` (documented by the DST usercommands API).
- Keep a small `c_mam_qa_*` console entry point only if command integration is unavailable in the installed build.
- Every mutating scenario checks server authority (`TheWorld.ismastersim` / `TheNet:GetIsServer()`) and refuses to run client-side.
- Require an explicit scenario name and an explicit QA-world confirmation.
- Expose `run`, `status`, `stop`, and `clean`; never accept arbitrary Lua source as a command.

No automatic run on world load. The host chooses when to start a scenario.

## Scheduling model

Use finite, sequential tasks:
- `TheWorld:DoTaskInTime` or entity `DoTaskInTime` to schedule the next test step.
- Keep task handles and cancel them on stop/failure/cleanup.
- No per-frame polling, no unbounded `DoPeriodicTask`, no recursive zero-delay loop.
- A bounded soak scenario may use a low-frequency interval (for example, 30–60 seconds) with a fixed maximum duration and sample count.
- Each scenario has a timeout, maximum spawned-entity count, maximum task count, and guaranteed cleanup path.

The queue runs one step at a time, records its result, yields to the simulation, and continues. On failure it records the first failure, runs cleanup, persists the report, and stops unless the scenario explicitly declares safe continuation.

## Fixture and world safety

- Use a dedicated disposable QA world with a backup; never use the user's primary save.
- Spawn only QA-owned prefabs or explicitly whitelisted vanilla prefabs.
- Track every spawned entity and temporary listener/task.
- Prefer hidden/isolated fixtures away from the player; avoid hostile AI and world-event side effects.
- Do not use `Kill()` as generic cleanup when it triggers loot/death behavior; use controlled removal for QA-owned entities.
- Remove temporary components/listeners and restore monkey-patched functions in a protected cleanup block.
- Never change world settings, save slots, or mod configuration from the runner.

## Report format and persistence

Use a versioned JSON report:
- `schema`, `run_id`, scenario name, start/end game time, outcome;
- environment facts that are safe and available: `BRANCH`, server/master-sim flags, loaded mod directory names;
- each assertion: ID, expected, observed, pass/fail, source file/API, severity;
- spawned entity IDs/prefabs, cleanup results, first error and traceback;
- explicit tier marker `L4` only when executed in the real DST engine with a loaded world.

### Persistence strategy

`TheSim:SetPersistentString(filename, data, encode, callback)` and `GetPersistentString` are documented. Since the API replaces a persistent string rather than providing append semantics, the runner should accumulate the complete report in memory and write it once at scenario completion (or at controlled checkpoints). Do not write on every tick/frame. Also print concise structured log lines with a stable prefix so the external QA agent can locate the run in the game log.

The exact persistent storage path and whether a host session writes to client or server storage must be verified on the installed build. Do not assume the 2016 community post's default `client_save` path is universal.

## First scenario groups

### A. Bootstrap and startup (L0/L4 boundary)
- Confirm runner and MAM mod initialization.
- Record enabled mod directory names.
- Capture first load-time error and phase.
- Do not infer startup compatibility from a world scenario that never reaches world load.

### B. Combat API contracts
- Compare CalcDamage's normal and special damage results.
- Test GetAttacked with and without spdamage.
- Test DoAttack with optional range/position overrides.
- Test DoAreaAttack with onlyontarget true/false and multiple candidates.
- Use controlled target health and verify expected deltas.
- Restore any temporary wrappers and remove all test entities.

### C. Smelter and forge lifecycle
- Valid/invalid loads, partial stacks, batch start, interruption, save/load, deferred completion, harvest retry.
- Compare authoritative server plan with client-visible replicated preview.
- Verify no duplicate output and no input loss.

### D. Containers and equipment
- Open/close, owner changes, equip/unequip, item removal, stack split/merge, overflow, save/load.
- Include player, supported NPC/follower owners and missing optional components where safe.

### E. Cleanup and soak
- Verify all QA entities removed, tasks cancelled, listeners detached and temporary overrides restored.
- Optional bounded 2-hour soak: sample every 30–60 seconds, cap entity/task counts, record memory/CPU only if a supported API exists, and stop on threshold breach. No per-frame instrumentation in normal builds.

## Interaction with Too Many Items

TMI remains useful for manual exploration and visual confirmation. It should not be required for deterministic regression cases: the runner should create its own known fixtures where possible. If a scenario requires a rare prefab or character state that the runner cannot safely construct, document TMI as a manual setup prerequisite and keep that test labeled manual rather than automated.

## External agent integration

When the desktop connection is available, a local helper can:
1. read the runner's structured game-log prefix and final persistent report;
2. correlate it with the Git commit, mod list and scenario;
3. request the next scenario through the approved in-game command interface;
4. stop on first failure and preserve the report/artifacts.

Do not build a filesystem polling loop inside the game. If external command transport is later needed, evaluate a local IPC bridge separately and require explicit permission before opening sockets or adding a local service.

## Tier and evidence rules

- **L0:** static parse, lint, source contracts.
- **L1:** isolated Lua tests/harnesses.
- **L2:** API contract and authority tests.
- **L3:** simulator/integration harness.
- **L4:** real DST engine, loaded disposable world, scenario and logs.
- **L5:** real host/client multiplayer, late join/reconnect and mod stack.

Only label a result L4/L5 when the actual game engine and required network topology were used. A Lua test harness is not L4.

## Research sources

- AddModUserCommand / permissions: https://vietnd69.github.io/dst-api-webdocs/docs/game-scripts/usercommands
- EntityScript DoTaskInTime: https://vietnd69.github.io/dst-api-webdocs/docs/game-scripts/entityscript
- Persistent string save/load: https://dst-api-docs.fandom.com/wiki/SetPersistentString and https://dst-api-docs.fandom.com/wiki/GetPersistentString
- Current Savedata utility overview: https://vietnd69.github.io/dst-api-webdocs/docs/game-scripts/util/savedata
- Console commands and server/client behavior: https://vietnd69.github.io/dst-api-webdocs/docs/game-scripts/consolecommands
- Persistence caveats (append unavailable in older community report): https://kleiforums.com/forums/topic/154842-can-a-dst-mod-export-data-into-a-file/
- Klei forum discussion of client/server persistent storage: https://kleiforums.com/forums/topic/68389-how-do-you-save-client-data-on-servers/

## Explicit non-goals

- No test runner implementation in this research-only document.
- No automatic world mutation on startup.
- No test execution against the user's primary save.
- No background filesystem/socket polling in Lua.
- No claim of L4/L5 until the runner has been installed and executed in the actual game.
