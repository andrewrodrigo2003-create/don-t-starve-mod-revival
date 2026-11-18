package.path = "dst-mods/metals_and_reforged/scripts/?.lua;" .. package.path

local recovery = require("mam/deconstruction")
local function always_success() return 0 end
local function always_fail() return 0.99 end

local standard_bronze = assert(recovery.BuildPlan("bronze_ingot", "generic", always_fail))
assert(#standard_bronze == 1 and standard_bronze[1].prefab == "copper_ore"
    and standard_bronze[1].count == 2,
    "standard recovery should apply fractional 75 percent recovery")

local bronze = assert(recovery.BuildPlan("bronze_ingot", "winona", always_fail))
assert(#bronze == 2, "Winona should recover both non-magical bronze components")
assert(bronze[1].prefab == "copper_ore" and bronze[1].count == 3)
assert(bronze[2].prefab == "iron_ore" and bronze[2].count == 1)

local adamantium = assert(recovery.BuildPlan("adamantium_ingot", "waxwell", always_fail))
assert(#adamantium == 1 and adamantium[1].prefab == "nightmarefuel"
    and adamantium[1].count == 3,
    "Maxwell should recover shadow material fully")

local wilson = assert(recovery.BuildPlan("adamantium_ingot", "wilson", always_fail))
assert(#wilson == 2, "Wilson should recover every exact alloy component")
assert(wilson[1].prefab == "iron_ingot" and wilson[1].count == 1)
assert(wilson[2].prefab == "nightmarefuel" and wilson[2].count == 3)

local specialist = assert(recovery.BuildPlan("copper_ingot", "wilson", always_fail))
assert(specialist[1].count == 3, "Wilson should have 100 percent recovery")
local base_success = assert(recovery.BuildPlan("copper_ingot", "generic", always_success))
assert(base_success[1].count == 3, "successful fractional rolls should recover all units")

-- Every current vanilla survivor has an explicit profile, even when the
-- justified behavior is the common baseline. Modded survivors use fallback.
for _, character in ipairs({
    "wilson", "willow", "wolfgang", "wendy", "wx78", "wickerbottom",
    "woodie", "wes", "waxwell", "wigfrid", "webber", "winona",
    "warly", "wortox", "wormwood", "wurt", "walter", "wanda",
}) do
    assert(type(recovery.GetRecoveryRate(character, "nonmagical")) == "number",
        "missing character recovery profile: " .. character)
end
assert(recovery.GetRecoveryRate("winona", "nonmagical") == 1)
assert(recovery.GetRecoveryRate("waxwell", "shadow") == 1)
assert(recovery.GetRecoveryRate("wilson", "lunar") == 1)
assert(recovery.GetRecoveryRate("wx78", "nonmagical") == 0.75)
assert(recovery.GetRecoveryRate("wickerbottom", "lunar") == 0.75)
assert(recovery.GetRecoveryRate("modded_survivor", "nonmagical") == 0.75)

-- The feature is strictly material-only: no crafted equipment, weapons,
-- armor, tools or structures may be dismantled.
for _, prefab in ipairs({
    "halberd", "forginghammer", "pithpike", "blacksmith_edge",
    "goldenaxe", "armormarble", "dragonflychest", "birdcage",
}) do
    assert(not recovery.IsSupported(prefab), "equipment unexpectedly supported: " .. prefab)
    assert(recovery.BuildPlan(prefab, "wilson", always_success) == nil,
        "equipment must not produce a dismantling plan: " .. prefab)
end

assert(recovery.IsSupported("copper_ore"))
assert(recovery.IsSupported("iron_ingot"))
assert(recovery.IsSupported("bronze_ingot"))
assert(recovery.IsSupported("moonglass_ingot"))
assert(recovery.IsSupported("adamantium_ingot"))
assert(recovery.IsSupported("goldnugget"))

-- Raw inputs and generic by-products have no safe reverse provenance. They
-- must stay out of the action until an explicit, non-upward conversion exists.
for _, prefab in ipairs({
    "copper_dust", "iron_dust", "gold_dust", "junk_dust",
    "redgem_shard", "bluegem_shard", "yellowgem_shard",
    "greengem_shard", "orangegem_shard", "purplegem_shard",
    "sharkscale",
}) do
    assert(not recovery.IsSupported(prefab),
        "material without a safe reverse rule must remain unsupported: " .. prefab)
end
-- Every MAM-owned material prefab has an explicit provenance disposition.
-- Only entries with a proven reverse path are eligible for the action; raw inputs,
-- ambiguous mixed by-products and loot-only materials remain intentionally excluded.
local expected_material_status = {
    copper_ore = "recoverable", copper_ingot = "recoverable",
    iron_ore = "recoverable", iron_ingot = "recoverable",
    goldnugget = "recoverable", gold_ingot = "recoverable",
    bronze_ingot = "recoverable", moonglass_ingot = "recoverable",
    adamantium_ingot = "recoverable",
    copper_dust = "raw_input", iron_dust = "raw_input", gold_dust = "raw_input",
    junk_dust = "mixed_byproduct",
    redgem_shard = "raw_gem_material", bluegem_shard = "raw_gem_material",
    yellowgem_shard = "raw_gem_material", greengem_shard = "raw_gem_material",
    orangegem_shard = "raw_gem_material", purplegem_shard = "raw_gem_material",
    sharkscale = "raw_creature_material",
}
local audited_prefabs = recovery.GetMaterialAuditPrefabs()
assert(#audited_prefabs == 20, "MAM material inventory changed; update provenance coverage")
for prefab, expected_status in pairs(expected_material_status) do
    local status, reason = recovery.GetMaterialAudit(prefab)
    assert(status == expected_status and type(reason) == "string" and reason ~= "",
        "missing or undocumented material provenance: " .. prefab)
    assert(recovery.IsSupported(prefab) == (expected_status == "recoverable"),
        "deconstruction allowlist disagrees with provenance: " .. prefab)
end
for _, prefab in ipairs(audited_prefabs) do
    assert(expected_material_status[prefab] ~= nil,
        "new MAM material needs a provenance decision: " .. prefab)
end
for prefab in pairs(expected_material_status) do
    assert(recovery.GetMaterialAudit(prefab) ~= nil,
        "material missing from audit inventory: " .. prefab)
end
assert(recovery.BuildPlan("unknown_metal", "wilson", always_success) == nil)


-- The War Bench prefab replicates the "prototyper" tag before SetPristine,
-- while its components.prototyper is server-only. Client RMB discovery must
-- use the replicated tag; the authoritative server check must require the component.
local client_station = {
    prefab = "warworkbench",
    HasTag = function(_, tag) return tag == "prototyper" end,
}
assert(recovery.HasWarWorkbench({ client_station }, false),
    "client should recognize the replicated War Bench prototyper tag without server components")
assert(not recovery.HasWarWorkbench({ client_station }, true),
    "server must reject a War Bench without the authoritative prototyper component")
local server_station = {
    prefab = "warworkbench",
    components = { prototyper = {} },
    HasTag = function(_, tag) return tag == "prototyper" end,
}
assert(recovery.HasWarWorkbench({ server_station }, true),
    "server should accept the real War Bench with its prototyper component")
local wrong_station = {
    prefab = "science_machine",
    components = { prototyper = {} },
    HasTag = function(_, tag) return tag == "prototyper" end,
}
assert(not recovery.HasWarWorkbench({ wrong_station }, false),
    "other prototypers must not count as the War Bench")
local untagged_station = {
    prefab = "warworkbench",
    components = { prototyper = {} },
    HasTag = function() return false end,
}
assert(not recovery.HasWarWorkbench({ untagged_station }, false),
    "client must reject a War Bench without the replicated prototyper tag")

print("PASS: material-only deconstruction, survivor profile resolution and unsupported equipment")

local native_inventory, native_container
if arg ~= nil and arg[1] ~= nil then
    local function load_component(name)
        local environment = setmetatable({
            Class = function() return {} end,
            GetGameModeProperty = function() return false end,
            require = function(module)
                assert(module == "equipslotutil" or module == "components/spdamageutil"
                    or module == "containers", "unexpected native dependency: " .. module)
                return {}
            end,
        }, { __index = _G })
        local chunk = assert(loadfile(arg[1] .. "/components/" .. name .. ".lua"))
        return setfenv(chunk, environment)()
    end
    native_inventory, native_container = load_component("inventory"), load_component("container")
end

local function action_fixture(options)
    options = options or {}
    local state = { spawned = {}, dropped = {}, removed = 0, given = 0, speech = {} }
    local function make_item(prefab, count, skin)
        local item = { prefab = prefab, skinname = skin, components = {}, valid = true }
        function item:IsValid() return self.valid end
        function item:Remove() self.valid = false end
        item.Transform = { SetPosition = function() end }
        item.components.inventoryitem = {
            cangoincontainer = true,
            canonlygoinpocket = options.pocket_only and prefab == "copper_ore",
            OnPickup = function() return false end,
            OnPutInInventory = function(self, owner) self.owner = owner end,
            OnRemoved = function(self) self.owner = nil end,
            GetSlotNum = function() return 1 end,
            OnDropped = function(self)
                self.owner = nil
                table.insert(state.dropped, item)
            end,
        }
        local stack = { maxsize = options.maxstack or 40, size = count or 1 }
        function stack:StackSize() return self.size end
        function stack:IsStack() return self.size > 1 end
        function stack:IsFull() return self.size >= self.maxsize end
        function stack:SetStackSize(size) self.size = size end
        function stack:Put(other)
            local source = other.components.stackable
            local amount = math.min(self:RoomLeft(), source:StackSize())
            self.size = self.size + amount
            source:SetStackSize(source:StackSize() - amount)
            if source:StackSize() == 0 then other:Remove(); return nil end
            return other
        end
        function stack:RoomLeft() return self.maxsize - self.size end
        function stack:CanStackWith(other)
            return item.prefab == other.prefab and item.skinname == other.skinname
        end
        function stack:Get(amount)
            amount = amount or 1
            assert(amount < self.size, "split must leave the original stack alive")
            self.size = self.size - amount
            return make_item(item.prefab, amount, item.skinname)
        end
        item.components.stackable = stack
        return item
    end
    state.make_item = make_item
    local doer = {
        prefab = "wilson", components = {}, PushEvent = function() end,
        Transform = { GetWorldPosition = function() return 0, 0, 0 end },
    }
    local function storage(count, filter, is_overflow)
        local result = {
            slots = {}, numslots = count, maxslots = count,
            acceptsstacks = not (is_overflow and options.no_stacks),
            readonlycontainer = is_overflow and options.readonly,
            inst = is_overflow and { components = {}, PushEvent = function() end } or doer,
            equipslots = {},
            itemtestfn = filter and function(_, item, slot) return filter(item, slot) end or nil,
        }
        local native = is_overflow and native_container or native_inventory
        if native ~= nil then setmetatable(result, { __index = native }) end
        result.itemslots = result.slots
        function result:GetSpecializedContainers() return nil end
        function result:CanTakeItemInSlot(item, slot)
            if native ~= nil then
                return native.CanTakeItemInSlot(self, item, slot)
                    and (filter == nil or filter(item, slot))
            end
            return not self.readonlycontainer
                and (not is_overflow or not item.components.inventoryitem.canonlygoinpocket)
                and (filter == nil or filter(item, slot))
        end
        function result:ShouldPrioritizeContainer(item)
            return is_overflow and options.priority and options.priority(item) or false
        end
        function result:GiveItem(item, slot)
            state.given = state.given + 1
            if options.reject_delivery then return false end
            if native ~= nil then return native.GiveItem(self, item, slot) end
            local function give_here(index)
                if not self:CanTakeItemInSlot(item, index) then return false end
                local existing = self.slots[index]
                local source = item.components.stackable
                if existing == nil then
                    if not self.acceptsstacks and source:StackSize() > 1 then
                        local part = source:Get(1)
                        self.slots[index] = part
                        part.components.inventoryitem.owner = self.inst
                        return false
                    end
                    self.slots[index] = item
                    item.components.inventoryitem.owner = self.inst
                    return true
                end
                local target = existing.components.stackable
                if self.acceptsstacks and target:CanStackWith(item) then
                    local amount = math.min(target:RoomLeft(), source:StackSize())
                    target:SetStackSize(target:StackSize() + amount)
                    source:SetStackSize(source:StackSize() - amount)
                    if source:StackSize() == 0 then item:Remove(); return true end
                end
                return false
            end
            if slot ~= nil then return give_here(slot) end
            for index = 1, count do
                if self.slots[index] ~= nil and give_here(index) then return true end
            end
            for index = 1, count do
                if self.slots[index] == nil and give_here(index) then return true end
            end
            return false
        end
        return result
    end
    local inventory = storage(options.slots or 2, options.inventory_filter, false)
    local overflow = options.overflow_slots and storage(options.overflow_slots,
        options.overflow_filter, true) or nil
    doer.components.inventory = inventory
    doer.components.talker = { Say = function(_, text) table.insert(state.speech, text) end }
    local original_give = inventory.GiveItem
    function inventory:GiveItem(item, slot)
        if slot ~= nil then return original_give(self, item, slot) end
        if overflow and overflow:ShouldPrioritizeContainer(item) and overflow:GiveItem(item) then
            return true
        end
        if original_give(self, item) then return true end
        return overflow ~= nil and overflow:GiveItem(item) or false
    end
    function inventory:GetOverflowContainer()
        return not options.ignoreoverflow and overflow or nil
    end
    function inventory:RemoveItem(item, whole)
        assert(whole == false, "only one input unit may be consumed")
        if options.remove_failure then return nil end
        state.removed = state.removed + 1
        if native_inventory ~= nil then return native_inventory.RemoveItem(self, item, whole) end
        if item.components.stackable:StackSize() > 1 then
            return item.components.stackable:Get(1)
        end
        assert(self.slots[1] == item)
        self.slots[1] = nil
        item.components.inventoryitem.owner = nil
        return item
    end
    local input = make_item(options.input or "copper_ingot", 2)
    input.components.inventoryitem.owner = options.foreign_owner and {} or doer
    inventory.slots[1] = input
    local actions = { HARVEST = { fn = function() return "vanilla-harvest" end } }
    local callbacks, handlers = {}, {}
    local environment = {
        STRINGS = { ACTIONS = {} },
        AddAction = function(name, label, fn)
            actions[name] = { str = label, fn = fn }
            return actions[name]
        end,
        AddComponentAction = function(kind, component, fn) callbacks[kind] = fn end,
        AddStategraphActionHandler = function(name, handler) handlers[name] = handler end,
        AddPopup = function() return {} end,
    }
    local global = {
        ACTIONS = actions,
        TheWorld = { ismastersim = options.client ~= true },
        TheSim = { FindEntities = function()
            return options.no_station and {} or { options.client and client_station or server_station }
        end },
        ActionHandler = function(action, name) return { action = action, state = name } end,
        SpawnPrefab = function(prefab)
            if prefab == options.spawn_failure then return nil end
            local item = make_item(prefab)
            table.insert(state.spawned, item)
            return item
        end,
        require = function(name)
            if name == "mam/deconstruction" then return recovery end
            if name == "mam/config" then
                return { get = function() return options.language or "en" end }
            end
            error("unexpected module: " .. name)
        end,
    }
    environment.GLOBAL = global
    setmetatable(environment, { __index = _G })
    local chunk = assert(loadfile("dst-mods/metals_and_reforged/initialise/modded_actions.lua"))
    setfenv(chunk, environment)()
    state.inventory, state.overflow, state.input = inventory, overflow, input
    state.callbacks, state.handlers, state.doer = callbacks, handlers, doer
    function state:run() return actions.MAM_DECONSTRUCT_METAL.fn({ doer = doer, invobject = input }) end
    function state:count(prefab)
        local total = 0
        for _, store in ipairs({ inventory, overflow }) do
            for _, item in pairs(store.slots) do
                if item.prefab == prefab then total = total + item.components.stackable:StackSize() end
            end
        end
        return total
    end
    return state
end

local passed, failed = 0, 0
local function scenario(name, fn)
    local ok, err = pcall(fn)
    if ok then passed = passed + 1 else failed = failed + 1 end
    print((ok and "PASS: " or "FAIL: ") .. name .. (ok and "" or (" - " .. tostring(err))))
end
local function rejected(state)
    assert(not state:run(), "action must reject before consuming input")
    assert(state.removed == 0 and state.input.components.stackable:StackSize() == 2)
    assert(state.given == 0 and #state.dropped == 0)
    for _, item in ipairs(state.spawned) do assert(not item:IsValid(), "staged output leaked") end
end

scenario("inventory receives full recovery and consumes one unit", function()
    local s = action_fixture()
    assert(s:run() and s.removed == 1 and s:count("copper_ore") == 3)
    assert(s.input.components.stackable:StackSize() == 1 and #s.dropped == 0)
end)
scenario("ordinary backpack receives output", function()
    local s = action_fixture({ slots = 1, overflow_slots = 1 })
    assert(s:run() and s:count("copper_ore") == 3 and #s.dropped == 0)
end)
scenario("full inventory rejects without consuming", function() rejected(action_fixture({ slots = 1 })) end)
scenario("backpack filter rejects metal", function()
    rejected(action_fixture({ slots = 1, overflow_slots = 1, overflow_filter = function() return false end }))
end)
scenario("inventory slot filters are respected", function()
    rejected(action_fixture({ inventory_filter = function() return false end }))
end)
scenario("read-only overflow is not writable", function()
    rejected(action_fixture({ slots = 1, overflow_slots = 1, readonly = true }))
end)
scenario("read-only existing stacks are not writable", function()
    local s = action_fixture({ slots = 1, overflow_slots = 1, readonly = true })
    s.overflow.slots[1] = s.make_item("copper_ore", 10)
    rejected(s)
    assert(s:count("copper_ore") == 10)
end)
scenario("pocket-only materials do not go to backpacks", function()
    rejected(action_fixture({ slots = 1, overflow_slots = 1, pocket_only = true }))
end)
scenario("disabled overflow is not counted", function()
    rejected(action_fixture({ slots = 1, overflow_slots = 1, ignoreoverflow = true }))
end)
scenario("non-stacking backpack needs three slots", function()
    rejected(action_fixture({ slots = 1, overflow_slots = 1, no_stacks = true }))
end)
scenario("non-stacking backpack receives separate units", function()
    local s = action_fixture({ slots = 1, overflow_slots = 3, no_stacks = true })
    assert(s:run() and s:count("copper_ore") == 3 and #s.dropped == 0)
    for _, item in pairs(s.overflow.slots) do assert(item.components.stackable:StackSize() == 1) end
end)
scenario("two alloy outputs cannot reserve one shared slot", function()
    rejected(action_fixture({ input = "bronze_ingot" }))
end)
scenario("slot-specific filters reject a conflicting alloy reservation", function()
    rejected(action_fixture({ slots = 1, input = "bronze_ingot", overflow_slots = 2,
        overflow_filter = function(_, slot) return slot == 1 end }))
end)
scenario("slot-specific filters accept compatible alloy outputs", function()
    local s = action_fixture({ slots = 1, input = "bronze_ingot", overflow_slots = 2,
        overflow_filter = function(item, slot)
            return slot == (item.prefab == "copper_ore" and 2 or 1)
        end })
    assert(s:run() and s:count("copper_ore") == 3 and s:count("iron_ore") == 1 and #s.dropped == 0)
end)
scenario("partial stacks and free slots receive exact quantities", function()
    local s = action_fixture({ slots = 3 })
    s.inventory.slots[2] = s.make_item("copper_ore", 39)
    assert(s:run() and s:count("copper_ore") == 42 and #s.dropped == 0)
end)
scenario("different skins cannot share a stack", function()
    local s = action_fixture()
    s.inventory.slots[2] = s.make_item("copper_ore", 1, "other-skin")
    rejected(s)
end)
scenario("small stack limits reserve multiple slots", function()
    local s = action_fixture({ slots = 3, maxstack = 2 })
    assert(s:run() and s:count("copper_ore") == 3 and #s.dropped == 0)
end)
scenario("small stack limits reject insufficient slots", function()
    rejected(action_fixture({ maxstack = 2 }))
end)
scenario("overflow priority cannot steal a reserved slot", function()
    local s = action_fixture({ input = "bronze_ingot", overflow_slots = 1,
        inventory_filter = function(item) return item.prefab ~= "iron_ore" end,
        priority = function(item) return item.prefab == "copper_ore" end })
    if s:run() then
        assert(s:count("copper_ore") == 3 and s:count("iron_ore") == 1 and #s.dropped == 0)
    else
        assert(s.removed == 0 and #s.dropped == 0)
    end
end)
scenario("spawn failure cleans up staged alloy outputs", function()
    rejected(action_fixture({ input = "bronze_ingot", slots = 3, spawn_failure = "iron_ore" }))
end)
scenario("failed input removal cleans up all outputs", function() rejected(action_fixture({ remove_failure = true })) end)
scenario("another owner's item is rejected", function() rejected(action_fixture({ foreign_owner = true })) end)
scenario("missing War Bench is rejected", function() rejected(action_fixture({ no_station = true })) end)
scenario("unsupported equipment is rejected", function() rejected(action_fixture({ input = "forginghammer" })) end)
scenario("remote client cannot execute authoritative recovery", function() rejected(action_fixture({ client = true })) end)
scenario("client discovers the action from replicated station tags", function()
    local s = action_fixture({ client = true })
    local actions = {}
    s.callbacks.INVENTORY(s.input, s.doer, actions, true)
    assert(#actions == 1 and s.handlers.wilson and s.handlers.wilson_client)
end)
scenario("full inventory message uses selected language", function()
    for _, language in ipairs({ "en", "ptbr" }) do
        local s = action_fixture({ slots = 1, language = language })
        rejected(s)
        assert(s.speech[1] == (language == "en" and "Make room for the recovered materials first."
            or "Libere espaço para os materiais recuperados."))
    end
end)
scenario("final input unit is consumed without leaving a phantom stack", function()
    local s = action_fixture()
    s.input.components.stackable:SetStackSize(1)
    assert(s:run() and not s.input:IsValid() and s.inventory.slots[1] == nil)
    assert(s:count("copper_ore") == 3 and #s.dropped == 0)
end)
scenario("multiple staged stacks share only their remaining capacity", function()
    local s = action_fixture({ slots = 3, maxstack = 2 })
    s.inventory.slots[2] = s.make_item("copper_ore", 1)
    assert(s:run() and s:count("copper_ore") == 4 and #s.dropped == 0)
end)
scenario("non-stacking storage cannot merge into an existing stack", function()
    local s = action_fixture({ slots = 1, overflow_slots = 1, no_stacks = true })
    s.overflow.slots[1] = s.make_item("copper_ore", 1)
    rejected(s)
    assert(s:count("copper_ore") == 1)
end)
scenario("compatible overflow priority is preserved", function()
    local s = action_fixture({ overflow_slots = 1, priority = function() return true end })
    assert(s:run() and s.overflow.slots[1].prefab == "copper_ore")
    assert(s.inventory.slots[2] == nil and #s.dropped == 0)
end)
scenario("invalid input is rejected without spawning output", function()
    local s = action_fixture()
    s.input:Remove()
    rejected(s)
    assert(#s.spawned == 0)
end)
scenario("server inventory is required", function()
    local s = action_fixture()
    s.doer.components.inventory = nil
    rejected(s)
    assert(#s.spawned == 0)
end)
scenario("unexpected delivery rejection preserves output on ground", function()
    local s = action_fixture({ reject_delivery = true })
    assert(s:run() and s.removed == 1 and #s.dropped == 1)
    assert(s.dropped[1]:IsValid() and s.dropped[1].components.stackable:StackSize() == 3)
end)
print(string.format("Deconstruction action runtime (%s): %d passed / %d failed",
    native_inventory ~= nil and "local DST inventory/container methods with stub entities" or "DST stubs",
    passed, failed))
assert(failed == 0, "deconstruction action regressions")
