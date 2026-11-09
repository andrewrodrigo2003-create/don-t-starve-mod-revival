# Weapon component compatibility

## Context

The current Metals and More Reforged code contains a legacy Forge combat extension in
`scripts/mod_main.lua`. It extends the vanilla `combat`, `weapon`, and replica
components for alternate attacks and damage modifiers.

The reported Woodie - Better Skill Tree crash is outside this repository:
its stack trace points to that mod's `modmain.lua` and a call to
`SetSpellFn`. The Metals and More weapon files inspected for this update use
a custom `aoespell` component (`SetAOESpell`), not
`components.spellcaster:SetSpellFn`. No direct call to `SetSpellFn` was
found in Metals and More Reforged.

## Compatibility changes

- Capture original component methods in callback-local variables instead of
  leaking generic `_old...` globals. The old globals were shared by every
  component instance and could be overwritten as more entities spawned.
- Preserve the original method for each component instance when wrapping
  attack range, hit range, damage calculation, attacks, and ranged attack checks.
- Correct alternate-attack condition evaluation: an absent condition allows
  the attack; a supplied condition must return true. Previously a false result
  was converted back to true by Lua's `or true` expression.

## Weapons

The weapons are **not removed** in this compatibility patch. The crash does not
establish that their custom `aoespell` component caused the failure, and
removing prefabs could make existing saved inventories lose items. The existing
`forge_weapons` setting continues to choose between the legacy weapon recipes
and the newer Forge-event recipes.

## Scope and verification limits

This change does not patch Woodie - Better Skill Tree, does not monkey-patch the
vanilla `spellcaster` component, and does not claim to fix its `SetSpellFn`
error.

The GitHub Actions run for PR #19 completed successfully (run 42):
- Every Lua file in Metals and More Reforged passed Lua 5.1 syntax parsing.
- All regression harnesses configured in the workflow passed, including
  `weapon_compatibility_contract_test.lua`.
- The installable mod ZIP is generated as a workflow artifact for this commit.

No DST in-game test has been run. Compatibility with Woodie - Better Skill Tree,
Gem Core, Glassic API, and Woodie Transformation Skins still requires a
controlled test in the game. This patch is a defensive compatibility improvement,
not a confirmed fix for the third-party `SetSpellFn` crash.


## Legacy Lucy projectile integration removal — 2.9.5

The old global alternate-projectile bridge has been removed from
`scripts/mod_main.lua`:

- Metals and More no longer injects a `weapon:SetProjectile` override.
- Alternate attacks no longer switch `weapon.projectile` or install a
  `CanRangedAttack` wrapper to expose a secondary projectile.
- The legacy third positional argument of `SetAltAttack` is retained as an
  ignored placeholder so existing calls do not shift their damage-type,
  damage-calculation, or condition arguments.
- The melee alternate-attack path, alternate damage/range/type handling, and
  normal vanilla projectile behavior are left intact.

The four Forge weapon prefabs remain registered. Their native `aoespell`,
`aoeweapon_leap`, `aoeweapon_lunge`, and parry components are preserved.
The normal Lucy axe is not replaced or modified by this change.

This removes Metals and More's old global alternate-projectile hook; it does
not patch Woodie - Better Skill Tree or establish that the third-party
`SetSpellFn` exception is fixed. That error remains outside this repository
and requires a separate in-game compatibility check.
