from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MOD = ROOT / "metals_and_reforged"
modinfo = (MOD / "modinfo.lua").read_text(encoding="utf-8")
modmain = (MOD / "modmain.lua").read_text(encoding="utf-8")
forgepack = (MOD / "initialise" / "modded_forgepack.lua").read_text(encoding="utf-8")

assert 'name = "legacy_forge_weapon_abilities"' in modinfo
assert 'name = "Legacy Forge weapon abilities"' not in modinfo
assert modinfo.count('label = "Legacy Forge weapon abilities"') == 1
assert 'default = false' in modinfo[modinfo.index('name = "legacy_forge_weapon_abilities"'):]
assert 'if GetModConfigData("legacy_forge_weapon_abilities") then' in modmain
assert 'if GetModConfigData("legacy_forge_weapon_abilities") then' in forgepack
stategraph_hook = modmain.index('AddStategraphPostInit("wilson"')
stategraph_guard = modmain.rfind('if GetModConfigData("legacy_forge_weapon_abilities") then', 0, stategraph_hook)
assert stategraph_guard > modmain.rfind("\nend", 0, stategraph_hook)
assert modmain.count('AddStategraphPostInit("wilson"') == 1
assert 'modimport("scripts/mod_main.lua")' in forgepack
assert 'if GetModConfigData("legacy_forge_weapon_abilities") and GetModConfigData("forge_weapons") then' in modmain
assert 'modimport("initialise/modded_pithpikemove.lua")' in modmain
assert 'modimport("initialise/modded_mace.lua")' in modmain
assert 'modimport("initialise/modded_stronger_bernie.lua")' in modmain
assert 'modimport("initialise/modded_forgepack.lua")' in modmain
print("Legacy Forge weapon ability gate: 12 checks passed")
