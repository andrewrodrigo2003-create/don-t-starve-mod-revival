-- Regression contract for the deprecated gold_ore migration prefab.
-- Run from the repository root with Lua 5.1:
--   lua5.1 dst-mods/tests/gold_ore_migration_test.lua

local MOD = "dst-mods/metals_and_reforged/scripts/prefabs/goldore.lua"
local passed = 0

local function check(condition, label)
    assert(condition, label)
    passed = passed + 1
end

local function instantiate(is_master)
    TheWorld = { ismastersim = is_master }
    TUNING = { STACK_SIZE_MEDITEM = 40 }

    local inst = {
        components = {},
        pristine = false,
        removed = false,
    }
    inst.entity = {
        AddTransform = function() end,
        AddAnimState = function() end,
        AddNetwork = function() end,
        SetPristine = function()
            inst.pristine = true
            inst.pristine_order = #inst.order + 1
            table.insert(inst.order, "pristine")
        end,
    }
    inst.order = {}
    function CreateEntity()
        return inst
    end
    inst.Transform = {
        SetPosition = function(_, x, y, z)
            inst.position = { x = x, y = y, z = z }
        end,
    }
    function inst:GetPosition()
        return self.position or { x = 0, y = 0, z = 0 }
    end
    function inst:AddComponent(name)
        self.components[name] = {}
        if name == "inventoryitem" then
            self.components[name].GetContainer = function() return self.owner_container end
            self.components[name].GetSlotNum = function() return self.owner_slot end
        elseif name == "stackable" then
            self.components[name].StackSize = function() return self.legacy_stack_size or 1 end
            self.components[name].SetStackSize = function(_, size)
                self.migrated_stack_size = size
            end
        end
        table.insert(self.order, "component:" .. name)
    end
    function inst:DoTaskInTime(delay, fn)
        self.task_delay = delay
        self.task = fn
    end
    function inst:Remove()
        self.removed = true
    end

    function MakeInventoryPhysics() end
    function Prefab(name, fn, assets)
        return { name = name, fn = fn, assets = assets }
    end

    local spawned
    function SpawnPrefab(name)
        assert(name == "goldnugget")
        spawned = {
            components = {
                stackable = {
                    SetStackSize = function(_, size) spawned.stack_size = size end,
                },
            },
            Transform = {
                SetPosition = function(_, x, y, z)
                    spawned.position = { x = x, y = y, z = z }
                end,
            },
        }
        return spawned
    end

    local prefab = dofile(MOD)
    local entity = prefab.fn()
    return entity, function() return spawned end
end

-- Client construction must call SetPristine before returning without server components.
local client = instantiate(false)
check(client.pristine, "client marks legacy prefab pristine")
check(client.components.inventoryitem == nil, "client skips server-only inventory components")
check(client.task == nil, "client does not schedule server migration")

-- Server construction also marks pristine before adding authoritative components.
local server, get_spawned = instantiate(true)
check(server.pristine, "server marks legacy prefab pristine")
check(server.order[1] == "pristine", "pristine is set before server components")
check(server.components.inventoryitem ~= nil and server.components.stackable ~= nil,
    "server creates migration components")
check(server.task_delay == 0.1 and type(server.task) == "function",
    "server schedules delayed migration")

-- Preserve the original stack and slot when held by an inventory/container component.
local received
local inventory_order = {}
local inventory = {
    RemoveItem = function(_, item, whole_stack)
        assert(item == server and whole_stack == true, "remove the original stack first")
        table.insert(inventory_order, "remove")
        return item
    end,
    GiveItem = function(_, item, slot, src_pos, drop_on_fail)
        received = { item = item, slot = slot, drop_on_fail = drop_on_fail }
        table.insert(inventory_order, "give")
        return true
    end,
}
server.owner_container = inventory
server.owner_slot = 5
server.legacy_stack_size = 7
server.task(server)
local held_gold = get_spawned()
check(received ~= nil and received.item == held_gold, "replacement is inserted into owner")
check(received.slot == 5, "replacement keeps original slot")
check(received.drop_on_fail == false, "failed container insertion cannot auto-drop elsewhere")
check(inventory_order[1] == "remove" and inventory_order[2] == "give",
    "legacy slot is freed before replacement insertion")
check(held_gold.stack_size == 7, "replacement preserves full legacy stack size")
check(server.removed, "legacy entity is removed after migration")

-- Preserve world position when the legacy ore is on the ground.
local ground, get_ground_gold = instantiate(true)
ground.legacy_stack_size = 3
ground.GetPosition = function()
    return { x = 12, y = 0, z = -4 }
end
ground.task(ground)
local dropped_gold = get_ground_gold()
check(dropped_gold.stack_size == 3, "ground replacement preserves stack size")
check(dropped_gold.position.x == 12 and dropped_gold.position.z == -4,
    "ground replacement preserves world position")
check(ground.removed, "ground legacy entity is removed after migration")

print(("PASS: %d gold_ore migration contracts"):format(passed))
