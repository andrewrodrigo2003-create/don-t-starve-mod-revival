# Better Wood Skill Tree — source and compatibility investigation

**Date:** 2026-11-09  
**Status:** preliminary; historical log and public Workshop metadata reviewed, full third-party source and in-game reproduction not yet available.

## User request

The user asked for deep inspection of their Don't Starve Together/Klei files, the Woodie - Better Skill Tree mod, and its Workshop package, using debugging, static/dynamic analysis, reverse engineering and related techniques to understand the crash and build compatibility with Metals and More Reforged. They clarified that the six crash logs were sent in earlier conversations and do not have a new test log yet.

## Confirmed historical evidence

The prior crash report recorded:
- Mod: **Woodie - Better Skill Tree**
- Workshop ID: `3516850707`
- Failing location: third-party `modmain.lua:1405`
- Error: `attempt to call method 'SetSpellFn' (a nil value)`
- Context: creation of prefab `lucy`; the historical stack/context also mentioned Woodie Transformation Skins, Glassic API and Gem Core.

This is historical evidence, not proof that the current versions still fail. It does not establish which mod owns the invalid call or which load-order interaction triggers it.

## Current public Workshop metadata

The public Steam Workshop page was reachable on 2026-11-09:
https://steamcommunity.com/sharedfiles/filedetails/?id=3516850707

The page currently displays a notice that the item has been removed from the community and is incompatible with DST. It still exposes metadata and description:
- title: Woodie - Better Skill Tree
- displayed version tag: 0.5
- displayed file size: 336.599 KB
- description includes Lucy throwable behavior, skill effects, and Lucy-related changes.

The public page did not provide the complete source archive in the inspected response. The local subscribed Workshop copy or an owner-provided archive is required to inspect the actual `modmain.lua`, `modinfo.lua`, and scripts at the version used by the old crash.

## Metals and More source inspection

The current `main` branch of `dst-mods/metals_and_reforged/scripts/mod_main.lua` was inspected. No direct `SetSpellFn` call was found in that file. The weapon extension still contains its own `SetAltAttack` behavior and unrelated component wrappers.

PR #20 is merged:
https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/pull/20

It removed Metals and More's legacy global alternate-projectile bridge:
- no injected `weapon:SetProjectile` override;
- no alternate-projectile state switch;
- no `CanRangedAttack` wrapper to expose a secondary projectile;
- the old third positional `SetAltAttack` argument remains as an ignored placeholder to preserve later argument positions;
- melee alternate attacks and the Forge weapons' native AOE/parry components remain.

PR #20 explicitly states that no DST in-game test was performed and the third-party `SetSpellFn` exception remains unverified. This is a defensive change, not a confirmed fix.

The current `docs/design/WEAPON_MOD_COMPATIBILITY.md` records the same limitation. No direct `SetSpellFn` reference was found in the Metals and More `mod_main.lua` inspected; a repository-wide source audit is still required before concluding there are no indirect paths.

## Vanilla API research

Klei's public modding guidance says the game's scripts are the practical API reference for modders; the community documentation points to the installed game's `data/databundles/scripts.zip` for vanilla Lua scripts. There is no complete official API reference.

Relevant sources:
- Klei modding guidance: https://support.klei.com/hc/en-us/articles/360029555992-Modding-Don-t-Starve-and-Don-t-Starve-Together
- Community explanation of scripts.zip: https://kleiforums.com/forums/topic/136505-how-to-get-developer-tools/
- Community API reference for `aoespell:SetSpellFn`: https://vietnd69.github.io/dst-api-webdocs/docs/game-scripts/components/aoespell
- Community API reference for `spellcaster:SetSpellFn`: https://vietnd69.github.io/dst-api-webdocs/docs/game-scripts/components/spellcaster

Important distinction: `SetSpellFn` exists on specific spell-related components, not on arbitrary entities or every Lucy/weapon component. A nil-method error means the object at the call site did not expose the expected method at that moment. The exact receiver expression and prefab/component initialization order in the third-party source are necessary to identify why.

## Analysis plan once source files are available

1. Preserve the original Workshop folder/archive read-only and record its version, Workshop ID, file hashes and timestamps.
2. Inspect `modinfo.lua`, `modmain.lua`, all Lua modules, prefab registrations, post-inits, component additions and asset declarations.
3. Find every `SetSpellFn` call and trace its receiver back to the entity/component constructor. Confirm whether it should be `aoespell`, `spellcaster`, or another object.
4. Compare the call with the exact vanilla DST `scripts.zip` from the game build used for the old log. Inspect the relevant component, prefab and mod loading code.
5. Trace Lucy creation and Woodie skill hooks; map load-order dependencies involving Woodie Transformation Skins, Glassic API and Gem Core.
6. Audit all Metals and More hooks touching `weapon`, `combat`, `lucy`, `SetAltAttack`, projectile behavior, `AddPrefabPostInit`, `AddComponentPostInit`, and relevant global callbacks.
7. Build a minimal reproduction matrix: Better Wood alone; Better Wood + vanilla; Better Wood + Metals and More; add each implicated mod one at a time; then test relevant load-order permutations.
8. Implement only a narrow compatibility-side adapter in Metals and More if its code is causally involved. Do not modify or redistribute third-party source without permission.
9. Add regression tests using the real affected module with controlled DST API stubs, then verify in an actual game world.
10. Record exact game build, mod versions, mod IDs, load order, server/client role and logs. Do not call a static/harness pass an in-game fix.

## Tool and file access limits observed during this pass

- The current session can inspect the GitHub repositories and the files surfaced in the connected conversation/library search.
- The surfaced Library results for this query were unrelated Cérebro Secundário setup logs and README material; no Better Wood source archive or DST scripts archive was found among those returned results.
- The current session does not expose a direct local Desktop filesystem or a Qoder workspace connector. It cannot truthfully claim to have inspected files that may exist only on the user's PC or inside Qoder.
- The personal memory search service was rate-limited during this pass, so no new Engram note contents could be retrieved.
- No decryption, DRM bypass, account-protection circumvention or protected Steam content extraction was attempted. The intended work is source inspection, archive extraction where legitimately accessible, static/dynamic debugging and API reverse engineering.

## Exact inputs still needed to complete source-level analysis

Only the files not accessible through the current connected repositories are needed:
- the local Workshop folder or ZIP for `workshop-3516850707` (especially `modmain.lua`, `modinfo.lua`, `scripts/`);
- the exact vanilla `scripts.zip` from the DST build associated with the old crash, if available;
- any old full crash log that is not present in the connected repository/history.

Do not ask the user to reproduce the crash before this source review. The historical log is enough to begin static analysis once the actual source package is available.
