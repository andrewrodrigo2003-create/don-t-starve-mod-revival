-- Static characterization of the optional legacy Forge item-pack combat extensions.
-- Known divergences remain dormant by default behind legacy_forge_weapon_abilities=false.
-- This file is imported by MAM via modimport("scripts/mod_main.lua").
-- L0 source audit only: no Klei components or runtime callbacks are executed.
local function read(path)
    local file = assert(io.open(path, "r"), "cannot read " .. path)
    local text = file:read("*a")
    file:close()
    return text
end

local source = read("dst-mods/metals_and_reforged/scripts/mod_main.lua")
local passed, failed = 0, 0
local known = 0

local function check(name, condition, is_known_divergence)
    if condition then
        passed = passed + 1
        if is_known_divergence then
            known = known + 1
            print("KNOWN API DIVERGENCE  " .. name)
        else
            print("SOURCE CHECK          " .. name)
        end
    else
        failed = failed + 1
        print("FAIL                  " .. name)
    end
end

-- Vanilla Combat:CalcDamage returns damage and special damage; preserve both.
check("CalcDamage wrapper preserves special damage return",
    source:find("local C, spdamage = old_calc_damage(self, A, z, B)", 1, true) ~= nil
        and source:find("return C, spdamage", 1, true) ~= nil)

-- Vanilla DoAttack accepts optional range and position arguments after instancemult.
check("DoAttack wrapper forwards optional range and position arguments",
    source:find("function self:DoAttack(T, z, U, x, V, ...)", 1, true) ~= nil
        and source:find("old_do_attack(self, T, z, U, x, W, ...)", 1, true) ~= nil)

-- Vanilla GetAttacked accepts a fifth spdamage argument and optional extensions.
check("GetAttacked wrapper forwards spdamage and optional arguments",
    source:find("function self:GetAttacked(G, X, z, x, spdamage, ...)", 1, true) ~= nil
        and source:find("old_get_attacked(self, G, X, z, x, spdamage, ...)", 1, true) ~= nil)

-- Vanilla DoAreaAttack accepts excludetags and onlyontarget; forward both.
check("DoAreaAttack wrapper forwards excludetags and onlyontarget",
    source:find("function self:DoAreaAttack(A, Y, z, Z, x, excludetags, onlyontarget, ...)", 1, true) ~= nil
        and source:find("old_do_area_attack(self, A, Y, z, Z, x, excludetags, onlyontarget, ...)", 1, true) ~= nil
        and source:find("if onlyontarget then", 1, true) ~= nil)

-- These hooks make the Forge pack's influence global, not limited to its weapons.
check("combat extension is installed through global AddComponentPostInit",
    source:find('"combat",', 1, true) ~= nil)
check("weapon, health, equippable and rechargeable components are extended",
    source:find('"weapon",', 1, true) ~= nil
        and source:find('"health",', 1, true) ~= nil
        and source:find('"equippable",', 1, true) ~= nil
        and source:find('"rechargeable",', 1, true) ~= nil)
check("client inventory and combat replicas are extended",
    source:find('components/inventoryitem_replica', 1, true) ~= nil
        and source:find('components/combat_replica', 1, true) ~= nil)
check("both Wilson server and client StateGraphs are post-initialized",
    source:find('"wilson"', 1, true) ~= nil
        and source:find('"wilson_client"', 1, true) ~= nil
        and source:find("AddStategraphPostInit", 1, true) ~= nil)

-- Global namespace/function replacement can collide with other mods.
check("damage type globals are assigned as a replacement table",
    source:find("_G.DAMAGETYPES =", 1, true) ~= nil, true)
check("EntityScript.GetDisplayName is replaced globally",
    source:find("_G.EntityScript:GetDisplayName()", 1, true) ~= nil, true)

local report = string.format(
    "Forge pack combat API contract: %d source checks passed, %d known global overrides recorded, %d failed",
    passed, known, failed
)
print(report)
if failed > 0 then error(report) end
