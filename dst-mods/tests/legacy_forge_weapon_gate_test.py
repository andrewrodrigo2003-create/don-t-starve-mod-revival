from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MOD = ROOT / "metals_and_reforged"
modinfo = (MOD / "modinfo.lua").read_text(encoding="utf-8")
modmain = (MOD / "modmain.lua").read_text(encoding="utf-8")
forgepack = (MOD / "initialise" / "modded_forgepack.lua").read_text(encoding="utf-8")

assert 'name = "legacy_forge_weapon_abilities"' in modinfo
assert 'name = "Legacy Forge weapon abilities"' not in modinfo
assert modinfo.count('label = "Habilidades antigas das armas da Forja / Legacy Forge weapon abilities"') == 1
assert 'default = false' in modinfo[modinfo.index('name = "legacy_forge_weapon_abilities"'):]
assert 'if GetModConfigData("legacy_forge_weapon_abilities") then' in modmain
stategraph_block = """if GetModConfigData("legacy_forge_weapon_abilities") then
    AddStategraphPostInit("wilson", function(self)
        local hit_state = self.states ~= nil and self.states.hit or nil
        local onenter = hit_state ~= nil and hit_state.onenter or nil
        if type(onenter) ~= "function" then
            return
        end

        hit_state.onenter = function(inst, ...)
            if inst:HasTag("parrying") then
                return inst.sg:GoToState("parry_pre")
            end
            return onenter(inst, ...)
        end
    end)
end"""
assert stategraph_block in modmain
assert modmain.count('AddStategraphPostInit("wilson"') == 1
assert 'local hit_state = self.states ~= nil and self.states.hit or nil' in modmain
assert 'if type(onenter) ~= "function" then' in modmain
assert 'return onenter(inst, ...)' in modmain
assert 'if GetModConfigData("legacy_forge_weapon_abilities") then' in forgepack
assert 'modimport("scripts/mod_main.lua")' in forgepack
assert 'if GetModConfigData("legacy_forge_weapon_abilities") and GetModConfigData("forge_weapons") then' in modmain
assert 'modimport("initialise/modded_pithpikemove.lua")' in modmain
assert 'modimport("initialise/modded_mace.lua")' in modmain
assert 'modimport("initialise/modded_stronger_bernie.lua")' in modmain
assert 'modimport("initialise/modded_forgepack.lua")' in modmain
print("Legacy Forge weapon ability gate: 10 checks passed")
