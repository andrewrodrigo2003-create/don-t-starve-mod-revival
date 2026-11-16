# Crash and Compatibility Triage

Use this record for every crash, startup error, script error, desync, missing prefab, recipe conflict or interaction failure reported by the user or players.

## Intake record

Create one entry per distinct report. Do not assume six logs mean six independent root causes; group only after comparing stack traces and reproduction conditions.

| Field | Required evidence |
|---|---|
| Report ID | Stable identifier, e.g. DST-CRASH-001 |
| First seen | Date/time and game build |
| Exact error | Full error text, not paraphrased |
| Stack trace | Entire trace, including file and line |
| Log source | server/client/crash log and timestamp |
| Mod versions | Metals and More commit/Workshop version plus relevant mods |
| Mod IDs/load order | Exact enabled mod IDs and order where available |
| Runtime role | Host, dedicated server, client, or single-player |
| Reproduction | Exact steps and frequency |
| Expected/actual | What should happen and what happened |
| Classification | Confirmed / likely / unverified |
| Root cause | Specific failing assumption or call chain |
| Fix | Files and behavior changed |
| Regression test | Test name and old-defect reproduction |
| Verification | Lua harness, CI, in-game, multiplayer, save/load |
| Status | New / investigating / reproduced / fixed / verified / blocked |

## Triage procedure

1. Preserve the original log verbatim and redact player names, local paths or identifiers only in copies shared publicly. Never discard stack-trace lines.
2. Extract the first meaningful Lua error and the complete call chain. Identify whether the fault begins in Metals and More, vanilla DST, another mod, or an interaction.
3. Search the exact function, prefab, component, event, RPC, recipe or asset path in the repository and relevant game scripts.
4. Reproduce with the smallest mod set:
   - vanilla + Metals and More;
   - the suspected external mod + Metals and More;
   - the user's full modpack if available.
5. Compare load order and versions. Test both orders when initialization order may matter.
6. Build a minimal Lua 5.1 harness using the actual affected module and only the necessary API stubs.
7. Add a regression test for the root cause. Test absent optional APIs and malformed/unexpected entities.
8. Apply the smallest compatibility-side fix. Never edit the external mod to hide the conflict.
9. Run syntax, focused harness, complete CI and relevant runtime checks.
10. Record what is still unknown. Do not call a harness pass an in-game pass.

## Compatibility patterns to prefer

- Check optional mod/API presence before use; validate both table and function shape.
- Guard entity/component access and lifecycle timing.
- Preserve previous callbacks and return values when wrapping shared hooks.
- Use unique namespaced identifiers for prefabs, tags, actions, events, netvars and globals.
- Avoid mutating shared recipe/loot tables in place unless the contract explicitly requires it.
- Make integration additive by default and provide safe fallback behavior.
- Revalidate entity, ownership, range, inventory capacity and server authority at action time.
- Fail closed for destructive or resource-consuming operations.
- Keep configuration switches honest: no visible setting without a working consumer.

## Special investigation: Better Wood Skill Tree / Woodie

The user reports an unresolved issue involving Better Wood Skill Tree. Earlier project notes mention a collision problem involving Woodie, but that is not yet proven to be the same defect.

- Treat the external mod as read-only.
- Do not assume the collision issue and the skill-tree issue share a cause.
- Obtain the exact error log and reproduction conditions before assigning a root cause.
- Test Metals and More with Better Wood Skill Tree disabled/enabled, and test load-order permutations.
- Trace whether Metals and More changes player stategraphs, locomotor/physics, tags, components, actions, combat, or Woodie-specific callbacks.
- Implement any fix only in Metals and More, with a regression harness and in-game verification.

## Special investigation: spell system independent of mod weapons

User requirement: the spell system must not require weapons supplied by Metals and More.

Audit all spell registration, item action, combat, projectile, component and prefab paths. Separate spell casting from weapon ownership/equipment checks. If a weapon is merely one optional casting focus, prove that an unarmed player can cast the spell and that a vanilla weapon or no weapon does not cause a nil access or blocked action. Do not remove legitimate weapon-specific abilities without checking the intended design. Add tests for:
- unarmed casting;
- vanilla weapon equipped;
- Metals and More weapon equipped;
- missing optional spell/weapon API;
- client request rejected/accepted by authoritative server;
- cooldown, resource cost, target validation and interrupted casts.

Do not claim this is fixed until code and behavior are verified.
