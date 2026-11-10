# DST Combat Wrapper Contract Audit — Metals and More Reforged

**Date:** 2026-11-10  
**Status:** Static compatibility findings; no gameplay patch applied  
**Scope:** Imported Forge combat framework in `dst-mods/metals_and_reforged/scripts/mod_main.lua`

## Reference profile and confidence

The comparison profile comes from the public DST combat API reference, documented as build 722832 (last updated 2026-04-21), and the public `vietnd69/dst-scripts` mirror. This is not the user's installed `scripts.zip`; signatures must be checked against the exact installed build before a runtime fix is approved.

- API reference: https://vietnd69.github.io/dst-api-webdocs/docs/game-scripts/components/combat
- Source mirror: https://github.com/vietnd69/dst-scripts/blob/main/components/combat.lua
- Lua multiple-return semantics: https://www.lua.org/manual/5.1/manual.html

## Findings

| MAM method | MAM implementation | Public API profile | Static risk |
|---|---|---|---|
| `CalcDamage` | Lines 162–184: captures `old_calc_damage(...)` into one local and returns one value | Returns `damage, spdamage` | Second result can be truncated; special/planar damage may be lost |
| `DoAttack` | Lines 242–247: accepts and forwards five arguments after `self`; transforms the instance multiplier | Accepts seven arguments after `self`, including `instrangeoverride` and `instpos` | Optional range and position overrides are not accepted/forwarded |
| `GetAttacked` | Lines 248–252: accepts and forwards four arguments after `self` | Accepts five arguments after `self`, including `spdamage` | Incoming special/planar damage may be dropped |
| `DoAreaAttack` | Lines 254–267: direct replacement, no captured previous implementation; accepts six arguments after `self` | Accepts seven arguments after `self`, including `onlyontarget`; returns hit count | Single-target-only mode may be ignored; custom implementation bypasses prior wrappers |

### Interacting special-damage loss

The MAM area attack currently calls:

`y.components.combat:GetAttacked(self.inst, self:CalcDamage(y, z, J), z, x)`

The `CalcDamage` call is not the final expression in the argument list. Under Lua 5.1, a function call in a non-final expression-list position contributes only its first result. Therefore `spdamage` is not forwarded by this call even before considering the `GetAttacked` wrapper's missing parameter.

This is a concrete source-level explanation for a possible special-damage loss path:
1. MAM `CalcDamage` wrapper captures only the first return.
2. MAM `DoAreaAttack` uses the result as a non-final call argument.
3. MAM `GetAttacked` wrapper does not accept/forward `spdamage`.

## Severity and confidence

- **High-priority compatibility candidates:** CalcDamage tuple truncation; GetAttacked missing spdamage; DoAttack missing optional trailing parameters.
- **High-priority behavior candidate:** DoAreaAttack ignores the public `onlyontarget` parameter and replaces the prior method.
- **Static confidence:** high that the MAM source has the described signatures and call expressions.
- **Installed-build confidence:** not yet established; the reference is public and may differ from the user's installed game version.
- **Runtime effect:** unverified. No L4 game runtime, character mod stack, Uncompromising Mode Beta, or multiplayer test was performed for these findings.

## Proposed minimal correction direction — not applied

After verifying against the installed scripts:
1. Capture and return both values from `old_calc_damage`, preserving the custom normal-damage calculation while returning the original `spdamage`.
2. Add and forward `instrangeoverride` and `instpos` in the DoAttack wrapper.
3. Add and forward `spdamage` in the GetAttacked wrapper.
4. Decide whether the custom DoAreaAttack should honor `onlyontarget` itself or delegate to the previous implementation in the appropriate path. Preserve the mod's intended area-attack balance and target filtering.
5. Add regression coverage for special/planar damage, optional attack range/position, single-target area attacks, and ordinary melee/projectile paths.

Do not apply these changes as a blind patch: the four methods interact, and a partial correction could leave the special-damage path broken or change area-attack behavior.

## Reproducible verification plan

1. Inspect the exact installed DST `scripts.zip` version and extract the corresponding `components/combat.lua` signatures.
2. Create a disposable QA world and backup; do not use the user's primary save.
3. Test weapon special damage and planar damage through ordinary `DoAttack`.
4. Test incoming special damage through `GetAttacked` with armor, saddle and damage resistance present.
5. Test MAM `DoAreaAttack` with `onlyontarget=true` and with normal area targeting.
6. Test `instrangeoverride` and `instpos` callers.
7. Repeat with the character/mod compatibility set and Uncompromising Mode Beta.
8. Compare logs and expected damage breakdown; only then prepare a minimal gameplay patch PR.

## Relationship to the AST auditor

The optional `tools/dst_wrapper_audit.py` now has a public-reference contract profile for `CalcDamage`, `DoAttack`, `GetAttacked` and `DoAreaAttack`. It can identify parameter-count mismatches, captured single-result patterns, and direct overrides without a same-block capture. The latest API-profile additions still require a fresh CI run; the earlier successful run #11 validated only the preceding prototype.
