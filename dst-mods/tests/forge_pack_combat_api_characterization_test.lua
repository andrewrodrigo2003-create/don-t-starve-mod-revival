-- Static characterization of the bundled Forge item-pack combat extensions.
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

-- Vanilla Combat:CalcDamage returns damage and special damage. The imported
-- wrapper captures only one return value and returns only that value.
check("CalcDamage wrapper captures only the first return value",
    source:find("local C = old_calc_damage(self, A, z, B)", 1, true) ~= nil
        and source:find("return C", 1, true) ~= nil, true)

-- Vanilla DoAttack also accepts instrangeoverride and instpos after instancemult.
check("DoAttack wrapper omits optional range and position arguments",
    source:find("function self:DoAttack(T, z, U, x, V)", 1, true) ~= nil
        and source:find("old_do_attack(self, T, z, U, x, W)", 1, true) ~= nil, true)

-- Vanilla GetAttacked accepts a fifth spdamage argument.
check("GetAttacked wrapper omits the spdamage argument",
    source:find("function self:GetAttacked(G, X, z, x)", 1, true) ~= nil
        and source:find("old_get_attacked(self, G, X, z, x)", 1, true) ~= nil, true)

-- Vanilla DoAreaAttack accepts the seventh onlyontarget argument.
check("DoAreaAttack wrapper omits onlyontarget",
    source:find("function self:DoAreaAttack(A, Y, z, Z, x, _)", 1, true) ~= nil, true)

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
    "Forge pack combat API characterization: %d source checks passed, %d known API divergences recorded, %d failed",
    passed, known, failed
)
print(report)
if failed > 0 then error(report) end
