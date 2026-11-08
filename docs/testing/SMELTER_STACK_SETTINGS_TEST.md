# Smelter stack acceptance: server/client configuration regression

## Problem

The smelter widget was created with `acceptsstacks = MAMConfig.on("mam_batch")`. DST runs container widget setup on the server component and on the client replica. A client with a different local setting could therefore expose a different stack policy from the authoritative server, despite the furnace already publishing its server configuration in the `mam_plan` netvar.

## Fix

The widget setup now resolves `acceptsstacks` from the published `c|batch|cap|growth` prefix whenever it is available. The local option is retained only as a temporary fallback before the first valid netvar value arrives. The helper rejects malformed/truncated values and protects against a netvar getter error. Because the first client widget setup can race the arrival of the netvar, the prefab also listens for `mamplandirty` and reruns widget setup only when the published batch setting differs from the current replica setting.

The server's own component continues to use its local setting before its first publication; that is the authoritative configuration. Client replicas use the synchronized value on their subsequent widget setup.

## Test

Run from the repository root:

```sh
texlua dst-mods/tests/smelter_stack_settings_test.lua
```

The committed harness contains 16 assertions:
- 8 direct policy cases covering server-on/off override, local fallback, empty/malformed/truncated config, and getter failure.
- 4 refresh-policy cases covering late server config arrival, matching settings, missing netvar, and missing replica container.
- 4 widget integration cases that load the actual `initialise/modded_cookers.lua` wrapper and check both directions of client/server mismatch, pre-netvar fallback, and preservation of the four furnace slots.

The policy helper earlier passed 8 isolated LuaTeX checks, and a separate local smoke harness using a minimal wrapper copy passed 4 checks. The committed full-repository harness subsequently passed all 16 assertions with Lua 5.1 in GitHub Actions (link below); live netvar timing and multiplayer remain untested.

## Boundary

These are isolated Lua tests, not a DST engine test. They do not validate the real container component/replica or netvar delivery timing. The prefab explicitly calls client `WidgetSetup("smelter")` on a zero-delay task; that path should be verified in a live multiplayer session with host and client options intentionally different.


## Lua 5.1 regression run

GitHub Actions parsed the changed integration files and ran the 16-assertion harness successfully: **16 passed; 0 failed**. Run: https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/actions/runs/42444807701

The combined integration snapshot also passed this 16-assertion harness while including the deferred client-widget guard and the actual component-to-helper config handshake: https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/actions/runs/42445185933

This does not replace live client/server netvar timing or in-game multiplayer validation.
