# DST Behavioral Simulator

Version 0.3.0 — deterministic core, server/client replication and StateGraph registration contracts.

This is a reusable behavioral test environment, not a recreation of the Klei engine. It currently models:
- virtual-time scheduling and cancellation;
- event delivery, listener tokens and owner-based cleanup;
- entity validity, tags, components and removal;
- prefab registration/spawning and a minimal world registry;
- item stacks and version-neutral container/inventory behavior;
- server-authoritative scalar values, revisioned snapshots, stale-update rejection and client dirty events;\n- StateGraph action-handler/state registration, keyed collision behavior and explicit mod-order permutations;\n- MAM global `containers.widgetsetup` wrapper delegation and custom payload behavior;\n- Bernie Big area-attack characterization against the public vanilla `DoAreaAttack` contract, including explicitly labeled known divergences.

Run from repository root:

```sh
lua5.1 dst-mods/tests/simulator_bootstrap_test.lua
lua5.1 dst-mods/tests/simulator_container_test.lua
lua5.1 dst-mods/tests/simulator_network_test.lua\nlua5.1 dst-mods/tests/stategraph_compatibility_test.lua\nlua5.1 dst-mods/tests/container_widget_compatibility_test.lua\nlua5.1 dst-mods/tests/combat_area_compatibility_characterization_test.lua
```

Evidence is limited to L1/L2 for isolated contracts and L3 for the combined deterministic scenarios. The network module is an explicitly designed simulator contract, not an implementation or verified reproduction of Klei netvars. No real DST runtime, rendering, physics, real networking transport, save system or game assets are emulated. StateGraph contracts are clean-room models of the public script mirror and still require comparison with the installed build.

All future simulator tests should import this shared bootstrap rather than define duplicate scheduler/event/entity stubs. Add API contracts only when a real mod path needs them, and record source/build provenance.
