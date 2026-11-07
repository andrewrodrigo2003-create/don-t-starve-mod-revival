local require = GLOBAL.require
local STRINGS = GLOBAL.STRINGS

STRINGS.NAMES.MARBLESEED = "Marble Seed"
STRINGS.NAMES.MARBLESEED_SAPLING = "Planted Marble Seed"
STRINGS.CHARACTERS.GENERIC.DESCRIBE.MARBLESEED = 
{
    GENERIC = "Looks just like a rock",
    PLANTED = "Why would someone plant a rock?"
}

AddPrefabPostInit("marbletree", function (inst)
    -- Loot e' autoritativo no servidor; no cliente isto so' criaria um componente
    -- local que ninguem consulta.
    if GLOBAL.TheWorld == nil or not GLOBAL.TheWorld.ismastersim then
        return
    end
    
    if not inst.components.lootdropper then inst:AddComponent("lootdropper") inst.components.lootdropper:SetChanceLootTable('marble_tree') end
    
    -- Os rolls de minerio (marbleseed, gold_dust, copper_ore e companhia) sairam
    -- daqui para initialise/modded_drops.lua, fonte "marbletree", com as chances
    -- intactas: assim a fonte pode ser desligada nas opcoes e passa pela mesma
    -- guarda aditiva que vale para as outras rochas e criaturas.
end)

local function ModifyTree(inst)
    
    local assets =
    {
        Asset("ANIM", "anim/marbleseed.zip")
    }
    
    local prefabs =
    {
        "marble",
        "marbleseed"
    } 
    
    local function handler_growfromseed(inst)
        inst:AddTag("NOCLICK")
        inst:DoTaskInTime(1.2, inst.RemoveTag, "NOCLICK")
        inst:DoTaskInTime(1.5, function()
            inst.AnimState:PlayAnimation("full_"..inst.animnumber)
            GLOBAL.MakeSnowCovered(inst)
            end)
        inst.AnimState:PlayAnimation("growing_"..inst.animnumber)
        inst.SoundEmitter:PlaySound("dontstarve/wilson/rock_break")
    end
    
    inst.AnimState:SetBank("marble_trees")
    inst.AnimState:SetBuild("marbleseed")
    
    inst.growfromseed = handler_growfromseed 
    
    if not inst.components.lootdropper then inst:AddComponent("lootdropper") inst.components.lootdropper:SetChanceLootTable('marble_tree') end

end

for i=1,4 do
    AddPrefabPostInit("marbletree_"..i, ModifyTree)
end