# DST Mod Engineering Playbook

**Purpose:** make every future mod update reproducible, diagnosable, testable and safer to release. This playbook applies to the DST mods maintained in this repository. The current active engineering target is **Metals and More Reforged**.

## Non-negotiable project boundaries

- Work only in the mod explicitly requested. For the current task, that is `dst-mods/metals_and_reforged`.
- Do not edit Better Lucy, Hydrated/Dehydrated, Uncompromising Mode, Better Wood Skill Tree, vanilla game files, or another Workshop mod to make Metals and More appear compatible.
- Compatibility fixes belong on the Metals and More side: defensive integration, feature detection, safe fallbacks, namespaced hooks, and tests.
- Preserve the user's explicit gameplay requirements. In particular, **the spell system must not require weapons from Metals and More**. Spells must remain independently usable; a weapon may be an optional delivery mechanism only if the user explicitly approves that design.
- Do not change art, animation, sound, or visual assets as part of code-only maintenance unless explicitly requested. Track these as a separate art/animation workstream.
- Preserve existing user changes and published history. Do not force-push, rebase/amend published commits, or merge without a reviewed integration step.
- Never claim that every Steam mod is compatible. State the tested game build, mod versions, combinations, and remaining gaps.

## Required workflow for every change

1. **Load context:** read this playbook, `AGENTS.md`, the master plan, the current roadmap, relevant design notes, current `main`, open issues/PRs, and recent commits.
2. **Define the contract:** write down the requested behavior, invariants, touched files, compatibility boundaries, multiplayer/server-authority implications, and acceptance tests.
3. **Reproduce:** obtain the complete crash log or a minimal deterministic reproduction. Record game build, mod version, enabled mod IDs, host/client role, world state, and reproduction steps.
4. **Trace root cause:** follow the call chain and data flow. Inspect the relevant vanilla API and third-party integration contracts at the exact supported version. Do not patch symptoms blindly.
5. **Implement a narrow fix:** one root cause per coherent change where practical. Namespace globals, guard optional APIs, avoid replacing other mods' tables/functions, and preserve original behavior when an integration is absent.
6. **Add regression coverage:** a test must fail for the old defect and pass for the corrected behavior when feasible. Include negative cases and load-order permutations.
7. **Verify in layers:** syntax -> module/harness -> API contract -> CI -> real DST world -> multiplayer/save-load where relevant.
8. **Independent review:** inspect the final diff for unintended changes, unsafe hooks, missing guards, duplicate registration, item loss/duplication, and regressions.
9. **Document evidence:** update changelog, compatibility matrix, known limitations, and the master plan. Separate verified results from assumptions.
10. **Release only when evidence supports it:** package the exact tested commit. Do not label a build stable if a required game-level test remains outstanding.

## Analysis and reverse-engineering methods

Use these methods where they answer a concrete question:

- Repository archaeology: Git history, blame, tags, original/rework comparisons, PRs and change provenance.
- Static analysis: syntax, global/function references, duplicate prefab names, asset references, registration order, unsafe overrides, dead code, and configuration consumers.
- Dynamic analysis: focused Lua 5.1 harnesses that load real project modules with minimal DST API stubs; test behavior, not only helper copies.
- API contract analysis: compare calls and component assumptions against the relevant vanilla DST scripts/API version and documented mod interfaces.
- Differential analysis: compare known-good and failing code paths, versions, load orders and configuration states.
- Fault injection: missing optional mod APIs, nil entities/components, invalid config values, full inventories, interrupted actions, disconnects and stale network messages.
- Performance analysis: identify hot hooks, repeated world scans, per-frame work, expensive serialization and network chatter; measure before optimizing.
- Compatibility analysis: test the mod alone, with each important dependency, with known conflict candidates, and with representative combined load orders.
- Security/robustness review: treat external mod APIs and network/client data as untrusted; server validates every gameplay mutation.

Reverse engineering is for interoperability, debugging, and understanding behavior. Record source, version, license/provenance and what was independently implemented. Do not copy protected code or assets without permission.

## DST-specific invariants

- Lua target: Lua 5.1. Keep syntax compatible with the game runtime.
- The server is authoritative for inventory, crafting, drops, resource consumption, ownership and world mutation. Client-side prediction/UI must not decide outcomes.
- Save/load and migration paths are part of behavior, not optional polish.
- Optional mods must be detected safely. Missing integrations must fall back to vanilla-safe behavior.
- Avoid global monkey-patching. Prefer namespaced APIs, additive hooks and guarded wrappers that preserve the previous function and return values.
- Recipe/loot edits must not silently erase other mods' additions. Prefer additive behavior and explicit conflict policies.
- Never allow duplicate items, free crafting, item loss, cross-player inventory access or progression bypasses.
- Any networked feature must handle host, dedicated server, client, late join, disconnect and stale requests.

## Definition of done

A change is done only when:
- the requested behavior is implemented;
- the focused regression test passes;
- all relevant Lua files parse under Lua 5.1;
- relevant harnesses and CI pass;
- the final diff has been independently inspected;
- in-game tests are recorded, or explicitly marked **not yet verified in-game**;
- compatibility claims match the exact evidence;
- changelog and master plan are updated;
- the deliverable points to the exact commit/package and lists remaining limitations.

## Current high-priority unresolved work

- Investigate the six distinct crash logs mentioned by the user; logs have not yet been attached to this engineering task, so no root cause is asserted.
- Resolve the reported Better Wood Skill Tree compatibility issue from complete logs and reproduction. Do not edit that external mod.
- Audit the spell implementation and remove any unintended dependency on Metals and More weapons, preserving the user's requirement that spells work independently.
- Fix the CI workflow so pushes to `main` and relevant pull requests consistently run the Lua 5.1 checks.
- Keep game-level, Uncompromising Mode Beta, multiplayer, save/load and user modpack validation explicit in the release checklist.

## Related documents

- [Crash and compatibility triage](CRASH_AND_COMPATIBILITY_TRIAGE.md)
- [Compatibility test matrix](COMPATIBILITY_TEST_MATRIX.md)
- [Metals and More Reforged master plan](METALS_AND_MORE_REFORGED_MASTER_PLAN.md)
- [Weapon compatibility design](design/WEAPON_MOD_COMPATIBILITY.md)
