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
error. The new Lua regression contract checks that the unsafe global captures
do not return and that false alternate-attack conditions remain false. Lua
syntax/CI and in-game loading still need to be verified after the pull request
is opened.
