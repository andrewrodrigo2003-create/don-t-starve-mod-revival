# Beyond the Forge — Codex & Expedition Progression Contracts

> Status: architecture/specification draft; no Lua runtime implementation in this change.
> Date: 2026-11-27
> Scope: DST PC; initial consumer is the existing Metals and More Reforged guide.
> Inspiration: Steam Workshop item 3842800115 (萌新任务手册 / beginner task handbook).
> Rights status of source mod: unknown/not verified. This is an independent design; do not copy its code, text, images, UI assets, or data.

## 1. Decision and sequencing

Build toward a reusable, data-driven Codex and objective model, but **do not create a new standalone gameplay module or force a new dependency now**. The Beyond the Forge charter requires stabilizing Metals and More Reforged before parallel expansions. The first milestone is a small, optional MAM-facing consumer of shared contracts. Promote the shared engine to Beyond the Forge Core only after a second real module needs it and the dependency boundary is proven.

The existing metallurgy reference book is a read-only feature in the MAM development branch `feature/full-crafting-rework-localization-2026-11-12`. It is not present in the inspected `main` tree and must not be represented as merged or release-ready. Preserve its guarantees: consulting the guide must not unlock recipes, craft remotely, consume book uses, or charge sanity.

## 2. Product boundaries

### Codex (read-only knowledge)
- Searchable/category-based entries for items, materials, recipes, stations, creatures, bosses, regions, mechanics, and module guides.
- Every entry has provenance, game/mod version applicability, and evidence status.
- Recipe facts come from the authoritative live registry/module data, not a second manually maintained UI list.
- Missing/partial content is explicit; never invent a recipe, drop, biome, or compatibility claim.
- The Codex never grants recipe unlocks or crafting authority.

### Expedition Journal (optional objectives)
- Tracks optional goals and multi-step objectives with prerequisites, progress counters, event/state conditions, and completion evidence.
- No mandatory daily chores, artificial time pressure, or reward economy in the first milestone.
- No automatic world edits, item grants, spawning, recipe unlocks, or destructive actions.
- Objectives remain optional and never gate ordinary vanilla/MAM progression.

### Test Lab / ModXpector (separate responsibility)
- May consume sanitized objective/test declarations as candidate scenarios.
- A gameplay objective is not automatically a test; a completed test is not automatically a completed player objective.
- ModXpector retains its own server authorization, allowlists, laboratory-mode gates, and assertion contracts. The Codex cannot bypass or broaden them.

## 3. Canonical data contracts (engine-neutral)

These are logical schemas, not claims that fields are already wired to a DST API.

### 3.1 Content entry

Required:
- `schema`: `btf/codex-entry/v1`
- `id`: stable namespaced ID, e.g. `mam:material:iron_ingot`
- `owner_module`: module identifier, e.g. `metals-and-reforged`
- `kind`: `item | material | recipe | station | creature | boss | region | mechanic | guide`
- `title_key`, `summary_key`: localization keys
- `source_refs`: internal prefab/recipe/registry identifiers or documented source references
- `applicability`: game/build/module version range when known
- `evidence`: `verified | observed | inferred | unknown`

Optional: `category`, `tags`, `icon_ref`, `related_ids`, `unlock_hint`, `body_key`.

Rules:
- IDs are stable and namespaced; display names are localized at render time.
- A missing source reference prevents numeric recipe/drop claims from being presented as verified.
- External content is data only; never evaluate code, callbacks, expressions, or executable strings from entries.
- Optional module entries are omitted or shown unavailable when their owner module is absent.

### 3.2 Objective definition

Required:
- `schema`: `btf/objective/v1`
- `id`, `owner_module`, `title_key`, `description_key`
- `steps`: ordered list (1–20 in initial profile)
- `optional`: must be true for the first milestone
- `version`: integer schema/content revision

Initial step kinds:
- `observe_event`: count an allowlisted game event.
- `reach_state`: verify a server-observed state predicate.
- `collect_count`: verify inventory count for a specific prefab at a defined observation boundary.
- `consult_entry`: record opening a Codex entry (local UI event; no world mutation).
- `manual_confirm`: player acknowledgement, labeled manual and never represented as automatic evidence.

A step may specify `target_id` or allowlisted `target_prefab`, bounded positive `required_count`, `prerequisites`, `completion_policy` (`server_observed | local_observed | manual`), and localization/evidence keys.

Rejected initially: arbitrary Lua/functions/callbacks/code strings/URLs/RPC names; arbitrary coordinates; spawning, attacks, crafting, consumption, item removal, recipe unlocks, worldgen changes; untrusted third-party objectives requesting world effects.

### 3.3 Player progress record

Logical shape:
- `schema`: `btf/player-progress/v1`
- `revision`: monotonic save revision
- `objectives`: map keyed by stable objective ID
- Per objective: `status` (`locked | available | active | completed`), `step_states`, bounded counters, optional `completed_at`, compact evidence summaries.

Unknown fields from newer schemas must not crash older readers; preserve or safely ignore according to migration policy. Do not store chat logs, unnecessary player identity, arbitrary mod payloads, or unbounded event histories.

## 4. Runtime authority and event flow

1. A module registers static, validated definitions during initialization.
2. Registry validates schema, IDs, owner module, step limits, target allowlists, prerequisites, and localization references.
3. Server-side adapters observe supported gameplay events or state transitions.
4. Progress engine evaluates only registered predicates and updates the authoritative player record.
5. Client receives a bounded, sanitized progress snapshot through a verified replication mechanism.
6. UI renders the snapshot; UI actions cannot directly mark server-observed steps complete.
7. Save/load persists the server-authoritative record using a verified DST mechanism.

Invariants:
- Server is authoritative for world-derived progress in multiplayer.
- Client-only actions may record only local UI consultation or explicitly manual confirmation.
- Duplicate callbacks/retries must not double-increment counters or complete objectives twice.
- Missing event/component/prefab/optional module means `unknown/unavailable`, not zero and not success.
- No polling all entities or continuous full-inventory scans. Prefer bounded listeners and targeted checks.
- Listener lifecycle is explicit: register once, unregister on teardown, handle player removal/world shutdown.
- No cross-player mutation; resolve player from authoritative runtime context, not untrusted payload fields.

## 5. Save migration and multiplayer

- Old saves start with an empty progress record.
- Every migration is deterministic, idempotent, and fixture-tested.
- Malformed progress must not reset unrelated MAM/vanilla save data.
- On migration failure, preserve original serialized data where safe, disable only the affected journal record, and emit bounded diagnostics.
- Server config determines enabled objectives; client UI reflects server snapshot.
- Do not replicate the whole Codex database or guide text as player netvars. Replicate compact progress; resolve static content locally by stable ID.
- Test host, remote client, dedicated server, reconnect, save/load, old save, missing optional module, and mismatched content version.
- Do not claim cross-shard/cluster progress without a demonstrated supported mechanism.

## 6. Compatibility and extension policy

- Each module owns its entries/objectives; shared infrastructure does not own gameplay facts.
- Optional integrations are capability-detected and isolated. Their absence cannot prevent base module loading.
- Do not patch third-party mods. Use documented public hooks only after validating the exact target build.
- Third-party declarations are untrusted data and may request read-only observation only; no executable callbacks or world-effect steps.
- A module without a Codex pack remains fully functional.
- Avoid global namespace pollution; add a namespaced registration surface only after lifecycle/collision behavior is verified.
- Localization keys are module-namespaced. English is baseline; pt-BR is required for the MAM-facing milestone.

## 7. Exact-build DST API verification gate

The community API docs consulted for this project describe an older build than the recorded DST build 762172. They are discovery aids, not final authority.

Before implementation inspect scripts shipped with the exact target build and confirm:
- player save/load lifecycle and component persistence;
- netvar type, initialization timing, dirty behavior, and client read path;
- event names/payloads for each objective adapter;
- prefab/component availability and Master/Client execution side;
- screen/widget lifecycle and safe access to player/world state;
- whether an RPC is needed (prefer none for this read-only/progress path; if required, define strict schema and server validation).

If an API cannot be confirmed, remove that adapter from the first milestone or use clearly labeled manual confirmation. Do not invent API names/signatures.

## 8. First implementation slice: MAM-only, read-only

1. Audit the MAM metallurgy book in its development branch and identify reusable internal code without altering read-only behavior.
2. Replace duplicated recipe facts with a read-only adapter to authoritative smelting registry where supported.
3. Add a small namespaced Codex index for MAM materials, stations, and guide pages only.
4. Do not add player objective persistence in the same patch. First validate the static read-only index, language, UI lifecycle, and absence of recipe-unlock side effects.
5. After that slice is validated in DST, add one optional non-rewarding objective with one verified event adapter and migration-safe player record.
6. Generalize into Beyond the Forge Core only when a second module has a concrete use case.

This avoids starting a second large project while MAM 2.9.7 and current ModXpector work remain unvalidated in-game.

## 8.1 MAM source audit — observed facts on the development branch

Inspected source on `feature/full-crafting-rework-localization-2026-11-12` (the same branch referenced by the open MAM PR #51 at the time of this audit):

- `scripts/smelting_products.lua` is the product definition table. In the inspected branch, every built-in product key in the `foods` table has a corresponding `PRODUCT_COSTS` entry, copied into `recipe.cost`; however, this descriptor is a consumption plan, not a complete formal encoding of every predicate alternative. The notable exception is `nitre`: its `test` accepts either the mineral path or a low-gem path, while `cost` describes the mineral path and `consume_all_if_unmatched` handles the gem fallback. A Codex must distinguish declared consumption metadata from the full predicate and must not execute recipe predicates to render a page.
- `scripts/smelting.lua` owns ingredient tags, recipe registration, candidate selection, and random result selection. `CalculateSmelterRecipe` performs weighted random selection; it is not a read-only documentation query and must never be called merely to populate the Codex.
- `scripts/mam/forecast.lua` exposes a preview path and consumes the server-published plan when a batch is active. It is a possible adapter boundary, but any UI consumer must be proven read-only and must not trigger the start/harvest action.
- `scripts/components/smelter.lua` is server-side stateful machinery and publishes a compact plan via the prefab's `mam_plan` net string. That is a useful existing pattern for presenting a bounded server snapshot, not a generic player-progress persistence API.
- `scripts/screens/metallurgybookscreen.lua` already builds the read-only book pages and recent-result page. It currently contains explanatory text for material chains and sources, so those strings must be audited against the authoritative registries before treating them as verified Codex facts.
- `tests/metallurgy_reference_book_contract_test.py` is located under `dst-mods/tests/` and protects book wiring, absence of prototyper/finiteuses behavior, recent-results behavior, and other guide contracts. It is a static contract test, not a live DST UI test.

**Concrete first-slice rule:** start with a read-only index over entries whose IDs and display names are present in the current MAM registries. Show the localized “Requirements not documented” label for products whose declarative `cost` metadata is absent; do not label them as mixed loads. Do not derive missing costs by reverse-engineering predicate closures during rendering. Keep the current book's read-only contract and add tests before extending the UI.

This source review is S1 (static inspection). It does not establish the exact DST runtime signatures, multiplayer behavior, save persistence, or in-game correctness.

## 9. Test and evidence matrix

Static/contract tests:
- duplicate IDs, invalid schema, unknown step kinds, oversized arrays, invalid counts, missing localization;
- unknown module, missing prefab/recipe, invalid prerequisite, prerequisite cycle;
- reject arbitrary code/function/RPC/world-effect fields;
- recipe data is read-only and sourced from authoritative registry;
- book open/close does not unlock recipes, craft, consume uses, or charge sanity;
- repeated events/callbacks do not double-count;
- bounded storage/diagnostics;
- migration from no record, oldest supported schema, malformed record, newer unknown schema.

Runtime scenarios (not yet executed):
- single-player and multiplayer host/client;
- dedicated server with remote client;
- save/load and reconnect;
- missing optional module and load-order variation;
- repeated event delivery and player removal during active objective;
- language switching and UI closure during refresh;
- MAM standalone vs Beyond the Forge Complete.

Evidence levels: S0 documentation; S1 static review; S2 isolated contract/harness; S3 simulation/instrumentation; S4 automated DST runtime; S5 manual in-game validation. S1/S2 do not prove S4/S5 compatibility.

## 10. Provenance

- Inspiration: [Steam Workshop item 3842800115](https://steamcommunity.com/sharedfiles/filedetails/?id=3842800115).
- Source code/license/permission for inspiration mod: not obtained or verified in this pass.
- Decision: study general product concept; independently design data model and implementation. No code, artwork, text, or expressive material from the Workshop item is included.
- Existing MAM guide design (development branch only): [design audit](https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/blob/feature/full-crafting-rework-localization-2026-11-12/docs/design/METALLURGY_REFERENCE_BOOK_AND_STATIONS.md).
- Existing ModXpector public suite contract (development branch): [community test suite API](https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/blob/security/modxpector-5.0.14-opt-in-2026-11-23/dst-mods/modxpector/docs/COMMUNITY_TEST_SUITE_API.md).

## 11. Acceptance gates

Ready for implementation planning only when:
- exact v3.0 operating directive and current MAM/ModXpector prompts are recovered and reconciled;
- exact-build DST APIs are inspected;
- current MAM branch and PR state are refreshed;
- no overlap/conflict with active MAM/ModXpector changes is found;
- first static Codex slice fits one small PR and does not block MAM stabilization.

This document is a design artifact, not implementation or in-game validation.


## 8.2 Follow-up source audit — recipe semantics and mining-source coverage (27/11/2026)

- The built-in product table and `PRODUCT_COSTS` currently have matching keys. Therefore, the generic `cost == nil` fallback in `metallurgybookscreen.lua` is principally a defensive path for externally registered/legacy products, not evidence that a built-in MAM recipe is a mixed load.
- The previous fallback label `Carga mista (receita legada)` / `Mixed load (legacy recipe)` was semantically unsafe. It has now been replaced in the MAM branch with “Requisitos não documentados” / “Requirements not documented”; the absence of a descriptor does not prove that the input is mixed.
- Do not flatten `recipe.test` into UI execution. The nitre predicate accepts an alternative low-gem path; its declared cost describes the mineral path and the smelting planner has a dedicated `consume_all_if_unmatched` fallback for eligible gem inputs. Any future Codex should expose the documented primary requirement and clearly label alternative/conditional behavior only when it has a safe declarative representation.
- The book's manual “Mining & sources” page previously omitted wild Rocky (excluding player-following Rocky), Slurtle, Snurtle, mined cave rubble, and ancient Ruins statues. These sources have now been added to the MAM page, which explicitly labels itself as a summary rather than an exhaustive catalog. The facts are still manually authored rather than generated from the source registry; future Codex work should derive them from validated registry metadata where possible.
- Preserve source conditions in any Codex entry: the extra-drop master switch and per-source toggles both apply; hound drops have Auto/Always/Never behavior and Auto yields to Uncompromising Mode; planted marble trees are deliberately excluded; player-following Rocky is excluded; Slurtle/Snurtle drops are additive-mode only and are not applied in Rewrite mode. A static list without these conditions would overstate availability.
- The “Materials & progression” page's stated alloy ratios for bronze, moonglass, and adamantium correspond to the inspected declarative cost descriptors. Keep them tied to those descriptors rather than duplicating independent numbers in a second registry. The dust-to-ore and ore-to-ingot progression descriptions should still be tested against the live ingredient-tag table and recipe rules before being marked verified.

Evidence: S1 static source inspection of `metallurgybookscreen.lua`, `smelting_products.lua`, `smelting.lua`, `mam/config.lua`, and `initialise/modded_drops.lua` on `feature/full-crafting-rework-localization-2026-11-12`. No Lua tests, DST runtime, multiplayer, UM, or in-game validation were executed in this follow-up.
- Follow-up on the revised book: the MAM page now includes the omitted source families and the Rewrite-mode cave-shell limitation. Static contract assertions were added; all 6 workflows passed at MAM HEAD `b47a98a17b19555c549a49018627abe469d104ae`. A subsequent tiny documentation-only caveat commit is awaiting its own CI refresh; the earlier 6/6 result must not be applied to later HEADs.

