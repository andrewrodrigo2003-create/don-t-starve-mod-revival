# DST Laboratory and Behavioral Simulator

## Local laboratory runner

The local MAM laboratory combines Lua syntax checks, 28 registered Lua harnesses, seven Python test scripts and three optional harnesses using supplied DST sources. It includes tool-gated crafting, material-only deconstruction, station/storage localization and the shared simulator. It does not execute the Better Lucy harness or change other mods.

Requirements: Python 3, Lua 5.1 and its `luac` compiler. The Python runner uses only the standard library. Git is optional for execution; unavailable repository metadata is reported explicitly. Nothing is downloaded or installed.

Run from the repository root:

```sh
python -B dst-mods/tests/run_lab.py --lua lua5.1 --luac luac5.1 --output dst-lab-report.json
```

Executable arguments accept names on PATH or file paths. On Windows, quote full paths containing spaces. The runner may also be invoked by its full path from another directory; it sets each test's working directory, including the MAM configuration harness. `--output` is relative to the invoking directory unless absolute.

To additionally exercise selected methods from trusted, locally extracted DST sources:

```sh
python -B dst-mods/tests/run_lab.py --lua lua5.1 --luac luac5.1 --dst-scripts "path/to/extracted/scripts" --timeout 120 --output dst-lab-native-report.json
```

The reference directory must contain `actions.lua`, `strings.lua`, `recipes.lua`, `speech_wilson.lua`, `components/{inventory,container,builder,builder_replica,inventory_replica,tool,finiteuses}.lua` and `widgets/redux/craftingmenu_hud.lua`. The runner records SHA256 hashes, not copies of these sources. Supplied sources run with stub entities; their origin and game build are not automatically verified. This is not an in-game test.

### Reports and failure handling

- Each output path must be new and its parent directory must exist. Existing reports are never overwritten; choose another filename to repeat a run.
- JSON schema `dst-lab/v1` records check status, commands, working directories, logs, tool versions, timestamps, Git branch/HEAD and local changes.
- SHA256 fingerprints cover the discovered Lua files, registered Python tests, the runner and optional reference sources. Changes during execution fail the integrity check. These fingerprints do not certify all package assets or the complete game installation.
- `--timeout` limits each subprocess separately, in seconds; it must be finite and positive. The default is 120. Failed checks do not prevent the remaining checks from running.
- Missing registered scripts, unavailable tools, incompatible Lua versions, failures and timeouts never become passes. Missing native sources are blocking when `--dst-scripts` was requested; without that option, the three additional checks are `not_run`.
- Exit codes: `0` means local checks passed, `1` means failed/blocked checks, `2` means invalid arguments or a report creation/write error, and `130` means interrupted execution with a partial report when writing succeeds.
- `mod_asset_reference_test.py` remains mandatory. A missing generated branding PNG is an asset failure, not a waived test; the runner does not generate or package it.
- CI, packaging, DST runtime, manual gameplay and multiplayer/mod-stack validation always remain `not_run`. This runner is not wired into CI by this update.

Run the runner's own regression tests independently, without Lua:

```sh
python -B tests/test_dst_lab_runner.py
```

The runner executes trusted local code; it is not an operating-system security sandbox. Review reports before sharing because they contain local paths, working-tree filenames and test logs.

### Evidence categories

| JSON category | Scope |
| --- | --- |
| `tooling` | Interpreter/compiler checks and infrastructure errors |
| `static` | Lua parsing and Python source/asset contracts |
| `harness` | Isolated behavior contracts and runner regression tests |
| `simulation` | Deterministic scenarios using the shared simulator |
| `native_script_harness` | Selected supplied DST Lua sources executed with stubs |
| `provenance` | Source-integrity result |

A passing subprocess is one check, not a count of every assertion inside it; full test output is retained. Categories describe the evidence actually collected, not a promotion to runtime validation or a compatibility certificate.

## Behavioral simulator

Version 0.3.0 — deterministic core, server/client replication and StateGraph registration contracts. The laboratory runner does not change this core version.

This is a reusable behavioral test environment, not a recreation of the Klei engine. It currently models:
- virtual-time scheduling and cancellation;
- event delivery, listener tokens and owner-based cleanup;
- entity validity, tags, components and removal;
- prefab registration/spawning and a minimal world registry;
- item stacks and version-neutral container/inventory behavior;
- server-authoritative scalar values, revisioned snapshots, stale-update rejection and client dirty events;
- StateGraph action-handler/state registration, keyed collision behavior and explicit mod-order permutations.

Related harnesses characterize MAM global `containers.widgetsetup` wrapper delegation, Bernie Big area attacks against the public vanilla `DoAreaAttack` contract with known divergences, and imported Forge pack combat wrappers against vanilla `Combat` method signatures. These isolated contracts are not evidence of a full simulator or engine implementation of those features.

Individual harnesses can still run from the repository root:

```sh
lua5.1 dst-mods/tests/simulator_bootstrap_test.lua
lua5.1 dst-mods/tests/simulator_container_test.lua
lua5.1 dst-mods/tests/simulator_network_test.lua
lua5.1 dst-mods/tests/stategraph_compatibility_test.lua
lua5.1 dst-mods/tests/container_widget_compatibility_test.lua
lua5.1 dst-mods/tests/combat_area_compatibility_characterization_test.lua
lua5.1 dst-mods/tests/forge_pack_combat_api_characterization_test.lua
```

Evidence is limited to isolated contracts and deterministic simulated scenarios. The network module is an explicitly designed simulator contract, not an implementation or verified reproduction of Klei netvars. No real DST runtime, rendering, physics, real networking transport, save system or game assets are emulated. StateGraph contracts are clean-room models of the public script mirror and still require comparison with the installed build.

All future simulator tests should import this shared bootstrap rather than define duplicate scheduler/event/entity stubs. Add API contracts only when a real mod path needs them, and record source/build provenance.
