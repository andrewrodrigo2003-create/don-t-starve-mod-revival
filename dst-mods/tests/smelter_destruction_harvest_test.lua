-- Regression harness for hammering the actual metal smelter prefab.
-- Run from the repository root with Lua 5.1.
-- DST entity APIs are narrowly stubbed; this is not an in-game test.

local captured
local function noop() end
Asset = function() return {} end
Prefab = function(name, fn) captured = { name = name, fn = fn }; return captured end
MakePlacer = function() return {} end
MakeObstaclePhysics = noop
MakeSnowCoveredPristine = noop
ACTIONS = { HAMMER = "HAMMER" }
TUNING = { HAUNT_TINY = 0.1 }
TheWorld = { ismastersim = true }
FRAMES = 1 / 30
net_string = function()
    return { set = function(self, value) self.value = value end }
end
package.preload["mam/container_settings"] = function()
    return { needs_widget_refresh = function() return false end }
end

local current_smelter
local function make_inst()
    local inst = {
        GUID = 1,
        components = {},
        removed = false,
        Transform = { GetWorldPosition = function() return 1, 2, 3 end },
        Light = { Enable = noop, SetRadius = noop, SetFalloff = noop, SetIntensity = noop, SetColour = noop },
        MiniMapEntity = { SetIcon = noop },
        AnimState = { SetBank = noop, SetBuild = noop, PlayAnimation = noop },
        SoundEmitter = { PlaySound = noop, KillSound = noop },
        entity = {
            AddTransform = noop, AddAnimState = noop, AddMiniMapEntity = noop,
            AddSoundEmitter = noop, AddLight = noop, AddNetwork = noop, SetPristine = noop,
        },
    }
    function inst:AddTag() end
    function inst:ListenForEvent() end
    function inst:DoTaskInTime() end
    function inst:Remove() self.removed = true end
    function inst:AddComponent(name)
        if name == "container" then
            self.components.container = {
                WidgetSetup = noop,
                DropEverything = function(c) c.dropped = true end,
            }
        elseif name == "inspectable" then
            self.components.inspectable = {}
        elseif name == "playerprox" then
            self.components.playerprox = { SetDist = noop, SetOnPlayerFar = noop }
        elseif name == "lootdropper" then
            self.components.lootdropper = {
                flung = {},
                dropped = false,
                fling_calls = 0,
                FlingItem = function(c, item)
                    c.fling_calls = c.fling_calls + 1
                    if c.fail_fling then error("simulated FlingItem failure") end
                    if c.fail_fling_on == c.fling_calls then return false end
                    table.insert(c.flung, item)
                    return true
                end,
                DropLoot = function(c) c.dropped = true end,
            }
        elseif name == "smelter" then
            self.components.smelter = current_smelter or {
                issmelting = false, canharvest = false,
                ResetSmelter = function(s) s.issmelting = false; return true end,
            }
        elseif name == "harvestable" then
            self.components.harvestable = {}
        elseif name == "workable" then
            self.components.workable = {
                SetWorkAction = noop,
                SetWorkLeft = function(c, value) c.workleft = value end,
                SetOnFinishCallback = function(c, fn) c.finish = fn end,
                SetOnWorkCallback = noop,
            }
        elseif name == "hauntable" then
            self.components.hauntable = { SetHauntValue = noop }
        end
    end
    return inst
end
CreateEntity = make_inst

dofile("dst-mods/metals_and_reforged/scripts/prefabs/metal_smelter.lua")
assert(captured and captured.name == "metal_smelter", "smelter prefab did not register")

local function make_product(prefab)
    local item = {
        prefab = prefab,
        removed = false,
        components = {
            stackable = {
                maxsize = 20,
                stacksize = 1,
                SetStackSize = function(self, amount) self.stacksize = amount end,
            },
        },
    }
    function item:IsValid() return not self.removed end
    function item:Remove() self.removed = true end
    return item
end

local fx = {
    Transform = { SetPosition = noop },
    SetMaterial = noop,
}
local product_attempts = 0
local fail_on_second_spawn = false
SpawnPrefab = function(name)
    if name == "collapse_small" then return fx end
    product_attempts = product_attempts + 1
    if fail_on_second_spawn and product_attempts == 2 then return nil end
    return make_product(name)
end

local passed = 0
local function check(name, condition)
    assert(condition, "FAIL: " .. name)
    passed = passed + 1
end

-- Failed staging must preserve the full ready output and the machine.
current_smelter = {
    issmelting = false, canharvest = true, product = "copper_ingot", batch = 45,
    ResetSmelter = function(s) s.issmelting = false; return true end,
}
local inst = captured.fn()
fail_on_second_spawn = true
inst.components.workable.finish(inst, {})
check("failed staging keeps furnace alive", not inst.removed)
check("failed staging drops no structure loot", not inst.components.lootdropper.dropped)
check("failed staging drops no container contents", not inst.components.container.dropped)
check("failed staging delivers no partial product", #inst.components.lootdropper.flung == 0)
check("failed staging restores hammer work", inst.components.workable.workleft == 1)
check("failed staging removes first temporary stack", product_attempts == 2)

-- Retry succeeds and returns the entire batch in correctly sized stacks.
product_attempts = 0
fail_on_second_spawn = false
inst.components.workable.finish(inst, {})
local flung = inst.components.lootdropper.flung
check("retry removes furnace only after delivery", inst.removed)
check("retry delivers three output stacks", #flung == 3)
check("retry stack quantities are 20/20/5",
    flung[1].components.stackable.stacksize == 20
        and flung[2].components.stackable.stacksize == 20
        and flung[3].components.stackable.stacksize == 5)
check("retry drops structure loot after product", inst.components.lootdropper.dropped)
check("retry drops container contents before removal", inst.components.container.dropped)

-- Partial delivery rejection retains only the undelivered remainder.
current_smelter = {
    issmelting = false, canharvest = true, product = "copper_ingot", batch = 45,
    ResetSmelter = function(s) s.issmelting = false; return true end,
}
local partial_inst = captured.fn()
partial_inst.components.lootdropper.fail_fling_on = 2
product_attempts = 0
fail_on_second_spawn = false
partial_inst.components.workable.finish(partial_inst, {})
check("partial delivery rejection keeps furnace alive", not partial_inst.removed)
check("partial delivery rejection preserves remaining batch", current_smelter.batch == 25)
check("partial delivery rejection keeps first delivered stack exactly once",
    #partial_inst.components.lootdropper.flung == 1
        and partial_inst.components.lootdropper.flung[1].components.stackable.stacksize == 20)
check("partial delivery rejection restores hammer work", partial_inst.components.workable.workleft == 1)
check("partial delivery rejection does not drop container or structure loot",
    not partial_inst.components.container.dropped and not partial_inst.components.lootdropper.dropped)
partial_inst.components.lootdropper.fail_fling_on = nil
partial_inst.components.workable.finish(partial_inst, {})
check("partial delivery retry destroys furnace after completion", partial_inst.removed)
check("partial delivery retry delivers only remaining 25 units",
    #partial_inst.components.lootdropper.flung == 3
        and partial_inst.components.lootdropper.flung[2].components.stackable.stacksize == 20
        and partial_inst.components.lootdropper.flung[3].components.stackable.stacksize == 5)

-- Active smelting is not destroyed when its transactional refund fails.
current_smelter = {
    issmelting = true, canharvest = false,
    ResetSmelter = function() return false end,
}
local active_inst = captured.fn()
active_inst.components.workable.finish(active_inst, {})
check("failed active rollback preserves furnace", not active_inst.removed)
check("failed active rollback preserves container", not active_inst.components.container.dropped)
check("failed active rollback restores hammer work", active_inst.components.workable.workleft == 1)

-- Idle destruction still drops the structure and its stored contents.
current_smelter = {
    issmelting = false, canharvest = false,
    ResetSmelter = function(s) s.issmelting = false; return true end,
}
local idle_inst = captured.fn()
idle_inst.components.workable.finish(idle_inst, {})
check("idle furnace can be destroyed", idle_inst.removed)
check("idle furnace drops contents", idle_inst.components.container.dropped)

print(("PASS: %d smelter destruction checks"):format(passed))
