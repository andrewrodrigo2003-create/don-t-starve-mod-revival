-- Regression harness for destroying a ready metal smelter.
-- Run from the repository root with Lua 5.1:
--   lua5.1 dst-mods/tests/smelter_destruction_harvest_test.lua
-- DST engine APIs are narrowly stubbed; this does not replace an in-game test.

package.path = "dst-mods/metals_and_reforged/scripts/?.lua;" .. package.path
package.preload["mam/container_settings"] = function()
    return { needs_widget_refresh = function() return false end }
end

local captured = {}
local noop = function() end
Asset = function() return {} end
Prefab = function(name, fn, assets, prefabs)
    captured.name, captured.fn, captured.assets, captured.prefabs = name, fn, assets, prefabs
    return { name = name }
end
MakePlacer = function() return {} end
MakeObstaclePhysics = noop
MakeSnowCoveredPristine = noop
ACTIONS = { HAMMER = "HAMMER" }
TUNING = { HAUNT_TINY = 0.1 }
TheWorld = { ismastersim = true }
FRAMES = 1 / 30
net_string = function()
    return { set = function(self, value) self.value = value end, value = function(self) return self.value end }
end

local function make_output(prefab, maxsize)
    local item = {
        prefab = prefab,
        components = {
            stackable = {
                maxsize = maxsize or 20,
                stacksize = 1,
                SetStackSize = function(self, value) self.stacksize = value end,
            },
        },
        removed = false,
    }
    function item:Remove() self.removed = true end
    return item
end

local function make_instance()
    local inst = {
        GUID = 123,
        components = {},
        removed = false,
        tags = {},
        Transform = { GetWorldPosition = function() return 1, 2, 3 end },
        AnimState = {
            SetBank = noop, SetBuild = noop, PlayAnimation = noop, PushAnimation = noop,
            OverrideSymbol = noop, IsCurrentAnimation = function() return false end,
        },
        MiniMapEntity = { SetIcon = noop },
        SoundEmitter = { PlaySound = noop, KillSound = noop },
        Light = { Enable = noop, SetRadius = noop, SetFalloff = noop, SetIntensity = noop, SetColour = noop },
        entity = {
            AddTransform = noop, AddAnimState = noop, AddMiniMapEntity = noop,
            AddSoundEmitter = noop, AddLight = noop, AddNetwork = noop, SetPristine = noop,
        },
    }
    function inst:AddTag(tag) self.tags[tag] = true end
    function inst:HasTag(tag) return self.tags[tag] == true end
    function inst:ListenForEvent() end
    function inst:DoTaskInTime() return { Cancel = noop } end
    function inst:AddComponent(name)
        local component
        if name == "container" then
            component = {
                WidgetSetup = function(self, widget) self.widget = widget end,
                DropEverything = function(self) self.dropped_everything = true end,
                Close = noop,
            }
        elseif name == "lootdropper" then
            component = {
                DropLoot = function(self) self.dropped_loot = true end,
                FlingItem = function(self, item)
                    self.flung = self.flung or {}
                    table.insert(self.flung, item)
                end,
            }
        elseif name == "smelter" then
            component = {
                canharvest = true,
                product = "copper_ingot",
                batch = 45,
                OnBuilt = noop,
            }
        elseif name == "workable" then
            component = {
                SetWorkAction = function(self, action) self.action = action end,
                SetWorkLeft = function(self, value) self.workleft = value end,
                SetOnFinishCallback = function(self, fn) self.finish = fn end,
                SetOnWorkCallback = function(self, fn) self.onwork = fn end,
            }
        elseif name == "playerprox" then
            component = { SetDist = noop, SetOnPlayerFar = noop }
        elseif name == "hauntable" then
            component = { SetHauntValue = noop }
        else
            component = {}
        end
        self.components[name] = component
    end
    function inst:Remove() self.removed = true end
    return inst
end
CreateEntity = make_instance

local fx = {
    Transform = { SetPosition = function(self, ...) self.position = { ... } end },
    SetMaterial = function(self, value) self.material = value end,
}
SpawnPrefab = function(name)
    return name == "collapse_small" and fx or make_output(name, 20)
end

local prefab = dofile("dst-mods/metals_and_reforged/scripts/prefabs/metal_smelter.lua")
assert(captured.name == "metal_smelter" and type(captured.fn) == "function",
    "metal smelter prefab did not register")
local inst = captured.fn()
local finish = inst.components.workable.finish
assert(type(finish) == "function", "hammer finish callback was not registered")

local passed = 0
local function check(name, condition)
    assert(condition, "FAIL: " .. name)
    passed = passed + 1
end

-- A transient failure on the second stack must roll back and preserve the
-- ready furnace, with no loot/container loss and no partial output.
local spawned = {}
local attempts = 0
SpawnPrefab = function(name)
    if name == "collapse_small" then return fx end
    attempts = attempts + 1
    if attempts == 2 then return nil end
    local item = make_output(name, 20)
    table.insert(spawned, item)
    return item
end
finish(inst, {})
check("failed demolition spawn restores workable", inst.components.workable.workleft == 1)
check("failed demolition leaves furnace alive", inst.removed == false)
check("failed demolition drops no loot", inst.components.lootdropper.dropped_loot ~= true)
check("failed demolition spills no container contents", inst.components.container.dropped_everything ~= true)
check("failed demolition flings no partial output",
    inst.components.lootdropper.flung == nil)
check("failed demolition removes prepared stacks",
    #spawned == 1 and spawned[1].removed == true)

-- Retrying now prepares and flings the full batch before removing the furnace.
attempts = 0
SpawnPrefab = function(name)
    if name == "collapse_small" then return fx end
    local item = make_output(name, 20)
    table.insert(spawned, item)
    return item
end
finish(inst, {})
local flung = inst.components.lootdropper.flung or {}
check("retry destroys furnace after complete preparation", inst.removed == true)
check("retry drops the furnace loot", inst.components.lootdropper.dropped_loot == true)
check("retry returns container contents before removal", inst.components.container.dropped_everything == true)
check("retry flings all output stacks", #flung == 3)
check("retry output sizes are 20/20/5",
    flung[1].components.stackable.stacksize == 20
        and flung[2].components.stackable.stacksize == 20
        and flung[3].components.stackable.stacksize == 5)
check("retry creates collapse effect", fx.material == "stone" and fx.Transform.position ~= nil)

print(("PASS: %d smelter demolition harvest checks"):format(passed))
