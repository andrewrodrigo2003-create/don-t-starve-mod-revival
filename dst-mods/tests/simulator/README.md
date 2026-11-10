# DST Behavioral Simulator

Version 0.2.0 — deterministic core plus a server/client replication contract.

This is a reusable behavioral test environment, not a recreation of the Klei engine. It currently models:
- virtual-time scheduling and cancellation;
- event delivery, listener tokens and owner-based cleanup;
- entity validity, tags, components and removal;
- prefab registration/spawning and a minimal world registry;
- item stacks and version-neutral container/inventory behavior;
- server-authoritative scalar values, revisioned snapshots, stale-update rejection and client dirty events.

Run from repository root:

```sh
lua5.1 dst-mods/tests/simulator_bootstrap_test.lua
lua5.1 dst-mods/tests/simulator_container_test.lua
lua5.1 dst-mods/tests/simulator_network_test.lua
```

Evidence is limited to L1/L2 for isolated contracts and L3 for the combined deterministic scenarios. The network module is an explicitly designed simulator contract, not an implementation or verified reproduction of Klei netvars. No real DST runtime, rendering, physics, real networking transport, save system or game assets are emulated.

All future simulator tests should import this shared bootstrap rather than define duplicate scheduler/event/entity stubs. Add API contracts only when a real mod path needs them, and record source/build provenance.
