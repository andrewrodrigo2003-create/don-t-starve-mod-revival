# Smelter stack acceptance: server/client configuration regression

## Problem

The smelter widget was created with `acceptsstacks = MAMConfig.on("mam_batch")`. DST runs container widget setup on the server component and on the client replica. A client with a different local setting could therefore expose a different stack policy from the authoritative server, despite the furnace already publishing its server configuration in the `mam_plan` netvar.

## Fix

The widget setup now resolves `acceptsstacks` from the published `c|batch|cap|growth` prefix whenever it is available. The local option is retained only as a temporary fallback before the first valid netvar value arrives. The helper rejects malformed/truncated values and protects against a netvar getter error.

The server's own component continues to use its local setting before its first publication; that is the authoritative configuration. Client replicas use the synchronized value on their subsequent widget setup.

## Test

Run from the repository root:

```sh
texlua dst-mods/tests/smelter_stack_settings_test.lua
```

The test loads the actual policy helper and covers conflicting client/server values in both directions, missing/empty/malformed/truncated config, and a failing netvar getter.

## Boundary

This is an isolated LuaTeX module test. It does not load DST's real container component/replica, validate netvar delivery timing, or replace a host/client in-game test. The prefab explicitly calls client `WidgetSetup("smelter")` on a zero-delay task; that path should be verified in a live multiplayer session with host and client options intentionally different.
