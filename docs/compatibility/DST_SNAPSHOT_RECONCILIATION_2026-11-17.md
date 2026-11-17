# DST snapshot reconciliation for Metals and More Reforged — 2026-11-17

**Status:** research handoff; no source code or game assets imported by this document.  
**Target candidate:** PR #51, branch `feature/full-crafting-rework-localization-2026-11-12`, HEAD `073299f55983e7fdf6a04fa0d9f295bf39ca58a0`.  
**Snapshot source:** canonical Second Brain repository, `Universos e Jogos/Don't Starve Together/06 - Testes e Diagnósticos/Arquivos para análise/Don't Starve Together/`.  
**Related audit:** Second Brain PR #152 (draft, not merged): `2026-11-17 - Auditoria abrangente do snapshot DST.md`, `2026-11-17 - Análise incremental dos assets de animação do DST.md`, and `2026-11-17 - Lote final do sync DST 1048-1111 UTC.md`.

## 1. What arrived in the DST snapshot

The Second Brain audit records a final sync checkpoint at `f954cfe13a3c6248a7eddb6078eef2942ce73cf1` (2026-11-17 11:11:25 UTC), with 56 sync commits since `fc44b465012eeb9b808cb03a63cc8a0462adfeea`. The inspected commit entries include 1,888 new `anim/*.zip` paths, 10 runtime binaries, and 19 Workshop manifests. Five new animation ZIP central directories were inspected; their internal animation/build/texture payloads were not decoded.

The same snapshot contains a preserved **Metals and More Reforged 2.9.6** source copy with 43 mod-owned animation ZIPs. It is a reference snapshot, not an installable 2.9.7 release. Its `CHANGELOG.txt` includes an **Unreleased — 2.9.7 compatibility follow-up (2026-11-14)** section and explicitly calls the changes an uncommitted local draft.

Do not copy the full vanilla animation archive, EXE/DLL runtime files, or third-party mod caches into the MAM repository. Preserve them in the Second Brain source archive and create derived indexes/reports only where useful.

## 2. Direct comparison: preserved 2.9.6 copy vs PR #51 candidate

Files were fetched from the preserved Second Brain snapshot and the PR #51 candidate and compared after normalizing CRLF/LF and trailing whitespace. This is a line-level difference inventory, not a semantic proof that one file is globally newer or safer.

| File | Preserved snapshot | PR #51 candidate | Assessment |
|---|---:|---:|---|
| `modinfo.lua` | 1 unique nonblank line | 7 | Candidate has the compatibility-mode legacy-ability option; retain candidate behavior pending config review. |
| `modmain.lua` | 5 | 6 | Candidate gates legacy Forge imports and uses the Cookbook icon for the guide; do not replace with snapshot. |
| `initialise/modded_ui_forecast.lua` | 15 | 18 | Candidate contains bilingual localization; retain candidate. |
| `scripts/mod_main.lua` | 45 | 36 | Snapshot contains additional defensive combat/equipment wrapper changes; review and port selectively with tests. |
| `scripts/components/smelter.lua` | 6 | 43 | Snapshot has a safer SpawnPrefab failure/remainder path; candidate has recent-forge-result persistence and publication for the guide. These behaviors must be merged, not file-replaced. |
| `scripts/mam/recipe_guard.lua` | 20 | 66 | Candidate has more complete preflight/atomic filter migration. Do not regress to snapshot implementation. |
| `CHANGELOG.txt` | 16 | 0 | Snapshot documents compatibility work and local test claims not yet represented in candidate changelog. Verify code and tests before recording as implemented. |

### 2.1 High-priority compatibility changes to investigate

The preserved snapshot's changelog describes these changes relative to the earlier `e929a83` draft:

1. Guard server weapon-replica access when a replica component is absent; an authoritative denial must not fall through into a client-side permission check.
2. Preserve vanilla temporary hit ranges, including explicit zero, and use previous methods when optional alternate ranges are absent.
3. Preserve prior `EntityScript.GetDisplayName` behavior for ordinary items and unknown name overrides.
4. Allow rechargeable equipment owners without the MAM buff component; preserve existing cooldown modifiers and unrelated modifiers.
5. Refresh rechargeable modifiers on owner equip/unequip changes and detach listeners from the old owner.
6. Avoid evaluating function-valued base damage twice while retaining multipliers, special damage, nested-call behavior and error cleanup.
7. Forward `from_ground`, trailing arguments and prior return values through equippable wrappers.

Static comparison confirms the current PR #51 `scripts/mod_main.lua` does not contain the snapshot's `old_get_display_name` wrapper; it also uses simpler alternate-range handling, does not preserve all wrapper varargs/returns in the shown Equip/Unequip methods, and assumes a buffable component in the rechargeable path. These are **candidate review targets**, not permission to copy the snapshot file wholesale.

The snapshot changelog claims 26 runtime-hook scenarios passed with DST API stubs (the earlier `e929a83` module reportedly failed 19), 21 Lua harnesses passed, and 127 Lua files parsed. It also says the checks were local, some asset/package checks were not run, and the work was an uncommitted draft. The harness files and exact commands/results must be located or reconstructed before treating those claims as reproducible evidence.

### 2.2 Smelter reconciliation

The snapshot's smelter includes a failure path around `SpawnPrefab(self.product)`: if output creation fails, the undelivered remainder stays pending rather than being silently lost. PR #51's smelter adds recent-result persistence for the last three completed forge outputs.

Required integration: preserve the current recent-result history and its save/network publication while bringing across only a verified retry-safe output-delivery path. Add a deterministic regression for nil return, thrown error, partial stack delivery, retry, and no duplicate output. Never replace the current component wholesale.

### 2.3 Recipe guard decision

The candidate's `recipe_guard.lua` contains more extensive preflight/atomicity behavior than the preserved snapshot. Keep the candidate implementation as the base. Review outstanding stacked PR #52 against the latest candidate before porting anything; do not reintroduce the snapshot's partial-mutation behavior.

## 3. Cross-mod evidence from the synced snapshot

These are concrete shared surfaces identified by static inspection:

| Integration | Shared surface | Work required |
|---|---|---|
| SmartCrockPot 4.02 (Workshop 365119238) | `widgets/containerwidget` / container widget lifecycle | Contract tests in both load orders; open/close cookpot, forge and chests; verify callbacks and cleanup. No reproduced crash is claimed. |
| Mineable Gems 2.20 (Workshop 380423963) and UM Beta | `LootTables`, shared loot tables and `LootDropper` | Verify additive drops and load order; preserve UM shared tables. No direct conflict is confirmed. |
| DST Equipment Switcher 1.33 (Workshop 503919639) | `Inventory.Equip`, `GiveItem`, `gotnewitem` listeners | Test argument/return preservation, slot/container swaps, and listener lifecycle. |
| HD Item Icon (Workshop 2260439333) | global `Image.SetTexture`, `TEMPLATES.MakeStartingInventoryWidget` | UI/atlas/scale regression checks with forge preview, inventory, crafting and character selection. |
| Better Lucy PT-BR 0.6.0 | `STRINGS.LUCY`, Woodie dialogue | Preserve string merges and test host/client localization; no direct MAM conflict is confirmed. |

The snapshot also includes a 57-mod test configuration and DST build 762172, but its Crash Never Mind errors point to the separate DST Mod Inspector copy. Do not attribute those errors to Metals and More.

## 4. Animation and asset research

The snapshot's vanilla animation ZIP names include useful references such as `glasscutter`, `goldenaxe`, `nightmare_axe`, `lunar_forge`, and many character/tool/structure families. Use them as references for DST-consistent animation banks, builds, symbols, and visual proportions after decoding and mapping them to vanilla prefabs/scripts.

The preserved MAM copy contains 43 mod-owned ZIPs. Build a manifest that records, for every ZIP: SHA-256, central-directory entries, compressed/uncompressed sizes, animation/build/atlas presence, prefab references, bank/build names, symbols and callers. Compare the manifest with the candidate branch before deciding whether any asset is missing or obsolete.

### Obsidian-workbench filename discrepancy

PR #51 removes `dst-mods/metals_and_reforged/anim/obsidian_workbench.zip`, while the preserved snapshot includes the old file. The current `warworkbench.lua` references `anim/workbench_obsidian.zip` and sets bank/build to `workbench_obsidian`; it does not reference `obsidian_workbench.zip` in the inspected prefab. This suggests the removed ZIP may be obsolete, but a full repository-wide reference/dependency check is still required before accepting the deletion. Do not restore or delete it based only on filename similarity.

## 5. Execution plan

1. Review the seven file comparisons above against the latest PR #51 HEAD, not just the historical `e929a83` baseline.
2. Port the combat/equipment wrapper improvements from the preserved snapshot one function at a time, preserving candidate behavior and adding focused Lua 5.1 contract tests.
3. Merge the smelter output-retry behavior with recent-result persistence; add nil/exception/partial-delivery/retry/no-duplication tests.
4. Reconcile #52 and #53 against the current PR #51 head; do not assume either stacked PR is already integrated.
5. Generate a manifest for the 43 MAM-owned animation ZIPs and map assets to prefabs/builds. Inspect vanilla references only as needed; do not vendor the vanilla game assets.
6. Expand compatibility contracts for SmartCrockPot, Mineable Gems/UM, Equipment Switcher and HD Item Icon.
7. Run the relevant CI and package checks on the exact new HEAD. Keep PRs draft and do not call the mod game-ready until the user's eventual in-game test.

## 6. Provenance and limits

- Snapshot checkpoint: `f954cfe13a3c6248a7eddb6078eef2942ce73cf1`.
- Preserved MAM files compared: `modinfo.lua` blob `b5f406097ed42953dbf2b9e516377ff28d834235`; `modmain.lua` `c8da23f834028234e37093fb59009c69a11e1e4b`; `initialise/modded_ui_forecast.lua` `b3329df2176a5c1789952a6b21692a5b8392672b`; `scripts/mod_main.lua` `a1b7ee0b3e4efcf3dbf0bef271f47c2a5da6b181`; `scripts/components/smelter.lua` `a37f16556bdb02ba5bb8d8f9d9d29577de22dd89`; `scripts/mam/recipe_guard.lua` `72088efc0e646a8efbd7136aa0b51bfb7d80677d`; `CHANGELOG.txt` `79717e3d0ca302039d2e5875aabdabd05cc30f75`.
- PR #51 candidate compared at `073299f55983e7fdf6a04fa0d9f295bf39ca58a0`.
- Evidence is static file inspection and normalized line comparison. No source file was modified, no local game runtime was executed, and no in-game behavior is certified by this report.
- The Second Brain PR #152 is a draft analysis record; its documentation is not merged to Second Brain main at the time of this report.
