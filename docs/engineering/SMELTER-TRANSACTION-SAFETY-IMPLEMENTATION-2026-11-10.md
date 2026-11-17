# Smelter Transaction Safety — Implementation Record

**Date:** 2026-11-10  
**MAM PR:** #44 — draft/open, not merged  
**Branch:** `fix/smelter-transaction-safety-main-2026-11-10`  
**Head:** `9b4cb5b8b2c1defc10c5252c7a1b61681c9b5a84`

## Implemented

Files changed:
- `dst-mods/metals_and_reforged/scripts/components/smelter.lua`
- `dst-mods/tests/smelter_component_lifecycle_test.lua`

### Input receipt preflight
Before consuming anything, `StartSmelting` now validates that:
- a non-empty consumption receipt exists;
- each referenced slot still contains a valid item with the expected prefab;
- each requested count is a positive integer and is available;
- no slot appears twice in the receipt.

A stale or malformed plan is rejected before input mutation. Each `ConsumeSlot` result is checked against the expected count and mismatches are logged.

This is a preflight/contract guard, not a fully rollback-capable database transaction. An unexpected third-party mutation during the synchronous consume loop remains a boundary requiring further runtime testing.

### Recoverable harvest output
If `SpawnPrefab(product)` fails during harvest:
- the remaining quantity is written back to `self.batch`;
- the machine remains in ready-to-harvest state;
- the output entitlement is not reset;
- a later harvest attempt resumes with the undelivered remainder, avoiding re-delivery of prior successful stacks.

A harvest callback without a valid inventory recipient is rejected without clearing the ready output. The harvest animation callback now runs only after the output has been delivered successfully, so a failed attempt does not visually switch the machine to empty.

### Deliberately unchanged
- Recipe costs, output quantities, batch limits, cook times and balance.
- Destruction policy when the machine is hammered during active smelting; this is still a design decision.
- Hammered-machine output spawn failure path; it needs a separate safe recovery design because the entity is being destroyed.
- Containers outside the smelter.
- Hydrated/Dehydrated and Better Lucy.

## Verification

GitHub Actions run: [42862006815](https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/actions/runs/42862006815)  
Conclusion: **success**.

Completed steps:
- Lua 5.1 parse of all Metals and More Lua files.
- All available Metals and More regression harnesses.
- Installable mod package build and artifact upload.

New lifecycle harness: **35 passed, 0 failed**. New cases cover stale receipt rejection without consuming input, output prefab failure preserving the pending batch, successful retry delivering only the remainder, ready-state preservation when no inventory recipient exists, and correct harvest callback timing.

Existing harnesses also passed, including smelting module **154/154**, ambiguous forecast **14/14**, stack settings **16/16**, metal storage chest, loot rewrite and weapon compatibility checks.

Package artifact:
- [metals-and-more-reforged-2.9.5.zip](https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/actions/runs/42862006815/artifacts/13785905724)
- SHA-256: `27e636374700620a0619c7655abc8e1f81a16f36b8cfd5225e89fd590eaac7ae`
- Artifact expires 2026-11-24.

## Local DST validation still required

The CI harness uses Lua 5.1 and narrow DST-facing stubs. It does not load the actual DST engine. Required local checks:
1. Start a disposable world with Metals and More Reforged enabled.
2. Build or spawn the metal smelter and run one known recipe with batch disabled.
3. Repeat with batch enabled and verify exact output count and leftovers.
4. Harvest normally; confirm machine returns to idle and can accept another load.
5. Save/reload while smelting and while ready to harvest; confirm no duplicate or missing output.
6. Test a full inventory; confirm output is safely delivered/dropped by the game's inventory behavior.
7. Repeat with Uncompromising Mode Beta and the usual mod stack.
8. Inspect client/server logs for Lua errors.

Use a disposable world and non-valuable test materials. Do not treat this PR as live-engine or multiplayer verified.

## Evidence boundary

Automated static parsing and Lua harnesses passed. Actual DST runtime, save/reload, UM Beta and multiplayer remain unverified. PR #44 remains draft/open and has not been merged into `main`.
