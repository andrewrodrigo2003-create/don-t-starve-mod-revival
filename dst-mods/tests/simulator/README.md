# DST Behavioral Simulator

Version 0.1.0 — deterministic core bootstrap.

This is a reusable test environment, not a recreation of the full Klei engine. It currently models:
- virtual-time scheduling and cancellation;
- event delivery, listener tokens and owner-based cleanup;
- entity validity, tags, components and removal;
- prefab registration/spawning and a minimal world registry.

Run from repository root:

```sh
lua5.1 dst-mods/tests/simulator_bootstrap_test.lua
lua5.1 dst-mods/tests/simulator_container_test.lua
```

Evidence is limited to L1/L2 for the implemented core and L3 only for the small combined bootstrap scenario. No real DST runtime, rendering, physics, networking, replicas, save system or game assets are emulated yet.

All future simulator tests should import this shared bootstrap rather than define duplicate scheduler/event/entity stubs. Add API contracts only when a real mod path needs them, and record source/build provenance.
