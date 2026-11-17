local root = "dst-mods/metals_and_reforged/"
local recipes = {}
for _, name in ipairs({ "boards", "woodie_boards", "boards_bunch", "cutstone", "cutstone_bunch", "rope", "transmute_cutstone" }) do
    recipes[name] = {
        name = name, product = name:find("boards") and "boards" or name:find("cutstone") and "cutstone" or name,
        ingredients = { { type = name:find("boards") and "log" or "rocks", amount = 3 } },
        character_ingredients = {}, tech_ingredients = {}, level = { ORPHANAGE = 0 }, numtogive = 1,
    }
end
local options = { mam_axe_crafting = true, mam_chisel_crafting = true }
local globals = { ACTIONS = { CHOP = { id = "CHOP" } }, GetValidRecipe = function(name) return recipes[name] end }
local env = setmetatable({ GLOBAL = globals, require = function(name)
    assert(name == "mam/config")
    return { on = function(key) return options[key] == true end }
end }, { __index = _G })
local gate = setfenv(assert(loadfile(root .. "scripts/mam/tool_crafting.lua")), env)()
local native, native_replica, native_inventory_replica, native_tool, native_uses, native_hud
local current
if arg[1] ~= nil then
    local native_env = setmetatable({
        Class = function() return {} end,
        require = function() return { BONUS_TECH = {} } end,
        GetValidRecipe = globals.GetValidRecipe,
        AllRecipes = recipes,
        IsRecipeValid = function(name) return recipes[name] ~= nil end,
        ShouldHintRecipe = function() return true end,
        CanPrototypeRecipe = function() return true end,
        PREFAB_SKINS_SHOULD_NOT_SELECT = {},
        RoundBiasedUp = function(value) return math.floor(value + 0.5) end,
        ProfileStatsAdd = function() end, NotifyPlayerProgress = function() end,
        SpawnPrefab = function(name)
            current.spawned = current.spawned + 1
            return { prefab = name, components = { inventoryitem = {} }, OnBuilt = function() end }
        end,
    }, { __index = _G })
    local function load(name)
        return setfenv(assert(loadfile(arg[1] .. "/components/" .. name .. ".lua")), native_env)()
    end
    native, native_replica = load("builder"), load("builder_replica")
    native_inventory_replica = load("inventory_replica")
    native_tool, native_uses = load("tool"), load("finiteuses")
    native_hud = setfenv(assert(loadfile(arg[1] .. "/widgets/redux/craftingmenu_hud.lua")), native_env)()
end

local function fixture()
    local s = { spent = 0, spawned = 0, outputs = 0, materials = 30, free = false, buffer = false }
    local inst = { components = {}, replica = {}, PushEvent = function() end, HasTag = function() return false end,
        GetPosition = function() return {} end }
    local inventory = { itemslots = {}, equipslots = {}, inst = inst }
    function inventory:GetActiveItem() return self.active end
    function inventory:GetOverflowContainer() return self.overflow end
    function inventory:Has(_, amount) return s.materials >= amount end
    function inventory:GiveItem(item) s.outputs = s.outputs + 1; s.product = item.prefab end
    function inventory:ConsumeByName(_, count) s.spent = s.spent + count; s.materials = s.materials - count end
    inst.components.inventory = inventory
    inst.replica.inventory = {
        GetItems = function() return inventory.itemslots end,
        GetEquips = function() return inventory.equipslots end,
        GetActiveItem = function() return inventory.active end,
        GetOverflowContainer = function() return inventory.overflow end,
        Has = function(_, ...) return inventory:Has(...) end,
    }
    local server = { inst = inst, freebuildmode = false, ingredientmod = 1, buffered_builds = {} }
    function server:HasIngredients(recipe)
        if type(recipe) == "string" then recipe = recipes[recipe] end
        return recipe ~= nil and (self.freebuildmode or s.materials >= recipe.ingredients[1].amount)
    end
    function server:IsBuildBuffered(name) return self.buffered_builds[name] end
    function server:SetBuildBuffered(name, value) self.buffered_builds[name] = value or nil end
    function server:GetIngredients(name) return { name = name }, false end
    function server:GetIngredientWetness() return 0 end
    function server:CheckIngredientsForMimic() return false end
    function server:RemoveIngredients(_, name)
        if not self.freebuildmode then inventory:ConsumeByName("material", recipes[name].ingredients[1].amount) end
    end
    function server:DoBuild(name, ...)
        local recipe = recipes[name]
        if recipe and (self:IsBuildBuffered(name) or self:HasIngredients(recipe)) then
            if recipe.canbuild then
                local ok, reason = recipe.canbuild(recipe, inst, ...)
                if not ok then return false, reason end
            end
            self:SetBuildBuffered(name, false)
            self:RemoveIngredients({}, name)
            s.spawned = s.spawned + 1
            inventory:GiveItem({ prefab = recipe.product })
            return true
        end
    end
    if native then
        server.HasIngredients, server.DoBuild = native.HasIngredients, native.DoBuild
    end
    inst.components.builder = server
    local client_inst = { components = {}, replica = { inventory = inst.replica.inventory } }
    if native_inventory_replica then
        client_inst.replica.inventory = setmetatable({ inst = client_inst, classified = inst.replica.inventory },
            { __index = native_inventory_replica })
    end
    local client = { inst = client_inst, classified = { isfreebuildmode = { value = function() return s.free end },
        bufferedbuilds = {}, _bufferedbuildspreview = {} } }
    for name in pairs(recipes) do client.classified.bufferedbuilds[name] = { value = function() return s.buffer end } end
    function client:IsFreeBuildMode() return self.classified ~= nil and s.free end
    function client:IngredientMod() return 1 end
    function client:HasIngredients(recipe)
        if self.classified == nil then return false end
        if type(recipe) == "string" then recipe = recipes[recipe] end
        return recipe ~= nil and (s.free or s.materials >= recipe.ingredients[1].amount)
    end
    function client:IsBuildBuffered() return s.buffer end
    if native_replica then
        client.HasIngredients, client.IsBuildBuffered = native_replica.HasIngredients, native_replica.IsBuildBuffered
    end
    gate.WrapBuilder(server, true)
    gate.WrapBuilder(client, false)
    function s:tool(kind, placement, owner)
        local tags = kind == "chisel" and { mam_stone_chisel = true } or { tool = true, CHOP_tool = true }
        local item = { prefab = kind == "chisel" and "mam_stone_chisel" or "axe", tags = tags, valid = true,
            components = { inventoryitem = { owner = owner or inst } } }
        function item:IsValid() return self.valid end
        function item:HasTag(tag) return self.tags[tag] == true end
        if kind ~= "chisel" then
            local tool = { actions = { [globals.ACTIONS.CHOP] = 1 } }
            function tool:CanDoAction(action) return self.actions[action] ~= nil end
            function tool:GetEffectiveness(action) return self.actions[action] or 0 end
            if native_tool then
                tool.CanDoAction, tool.GetEffectiveness = native_tool.CanDoAction, native_tool.GetEffectiveness
            end
            item.components.tool = tool
            item.components.finiteuses = { current = 10, GetUses = native_uses and native_uses.GetUses or function(self) return self.current end }
        end
        if placement == "equip" then inventory.equipslots.hands = item
        elseif placement == "active" then inventory.active = item
        elseif placement == "overflow" then
            local bag = { slots = { item }, inst = {}, readonlycontainer = false }
            function bag:GetItems() return self.slots end
            function bag:IsReadOnlyContainer() return self.readonlycontainer end
            inventory.overflow = bag
            item.components.inventoryitem.owner = bag.inst
        else inventory.itemslots[1] = item end
        return item
    end
    function s:build(name, ...)
        current = self
        return server:DoBuild(name, ...)
    end
    s.server, s.client, s.inst, s.inventory = server, client, inst, inventory
    return s
end

local passed, failed = 0, 0
local function test(name, fn)
    options.mam_axe_crafting, options.mam_chisel_crafting = true, true
    local ok, err = pcall(fn)
    if ok then passed = passed + 1 else failed = failed + 1 end
    print((ok and "PASS " or "FAIL ") .. name .. (ok and "" or (": " .. tostring(err))))
end
local function blocked(s, name)
    assert(not s.server:HasIngredients(name) and not s.client:HasIngredients(name))
    assert(not s:build(name) and s.spent == 0 and s.spawned == 0)
end
for _, name in ipairs({ "boards", "woodie_boards", "boards_bunch", "cutstone", "cutstone_bunch" }) do
    test(name .. " rejects missing tool", function() blocked(fixture(), name) end)
    for _, slot in ipairs({ "inventory", "equip", "active", "overflow" }) do
        test(name .. " accepts owned tool in " .. slot, function()
            local s = fixture()
            local item = s:tool(name:find("boards") and "axe" or "chisel", slot)
            assert(s.server:HasIngredients(name) and s.client:HasIngredients(name))
            assert(s:build(name) and s.outputs == 1 and s.spent == 3 and item:IsValid())
            assert(item.components.finiteuses == nil or item.components.finiteuses.current == 10)
        end)
    end
end
test("axe tiers and explicitly capable third-party tools", function()
    for _, name in ipairs({ "axe", "goldenaxe", "moonglassaxe", "lucy", "multitool_axe_pickaxe", "fumaroleaxe", "modded_chopping_tool" }) do
        local s = fixture(); local item = s:tool("axe"); item.prefab = name
        if name == "lucy" then item.components.finiteuses = nil end
        assert(s.client:HasIngredients("boards") and s:build("boards"))
    end
end)
for _, tag in ipairs({ "usesdepleted", "broken" }) do
    test("rejects " .. tag .. " tools on both sides", function()
        local s = fixture(); s:tool("axe").tags[tag] = true; blocked(s, "boards")
    end)
end
test("names alone cannot identify axes", function()
    local s = fixture(); s:tool("axe").tags = {}; blocked(s, "boards")
end)
test("invalid tools cannot satisfy a recipe", function()
    local s = fixture(); s:tool("axe").valid = false; blocked(s, "boards")
end)
test("server rejects forged tag without real tool", function()
    local s = fixture(); s:tool("axe").components.tool = nil
    assert(not s:build("boards") and s.spent == 0)
end)
test("server rejects zero effectiveness", function()
    local s = fixture(); s:tool("axe").components.tool.actions[globals.ACTIONS.CHOP] = 0
    assert(not s:build("boards") and s.spent == 0)
end)
test("server rejects depleted uses even before tag replication", function()
    local s = fixture(); s:tool("axe").components.finiteuses.current = 0
    assert(not s:build("boards") and s.spent == 0)
end)
test("server rechecks transfer after menu availability", function()
    local s = fixture(); local item = s:tool("axe")
    assert(s.client:HasIngredients("boards")); item.components.inventoryitem.owner = {}
    assert(not s:build("boards") and s.spent == 0)
end)
test("dropping tool immediately blocks crafting", function()
    local s = fixture(); s:tool("axe"); s.inventory.itemslots = {}; blocked(s, "boards")
end)
test("read-only backpack cannot supply tools", function()
    local s = fixture(); s:tool("axe", "overflow"); s.inventory.overflow.readonlycontainer = true; blocked(s, "boards")
end)
test("chisel requires both dedicated identity and tag", function()
    local s = fixture(); s:tool("chisel").prefab = "razor"; blocked(s, "cutstone")
    s = fixture(); s:tool("chisel").tags = {}; blocked(s, "cutstone")
end)
test("missing authoritative inventory cannot fall back to replica", function()
    local s = fixture(); s:tool("axe"); s.inst.components.inventory = nil
    assert(not s:build("boards") and s.spent == 0)
end)
test("client without classified state stays unavailable", function()
    local s = fixture(); s:tool("axe"); s.client.classified = nil
    assert(not s.client:HasIngredients("boards"))
end)
test("client without inventory replica stays unavailable", function()
    local s = fixture(); s.client.inst.replica.inventory = nil
    assert(not s.client:HasIngredients("boards"))
end)
test("buffered build stays queued while its tool is missing", function()
    local s = fixture(); s.server.buffered_builds.boards = true; s.buffer = true
    assert(not s.client:IsBuildBuffered("boards") and not s:build("boards"))
    assert(s.server.buffered_builds.boards and s.spent == 0)
    s:tool("axe")
    assert(s.client:IsBuildBuffered("boards") and gate.CanCraft(s.server, "boards", true))
    assert(s.server.buffered_builds.boards and s.spent == 0)
end)
test("freebuild exception agrees on client and server", function()
    local s = fixture(); s.server.freebuildmode = true; s.free = true; s.materials = 0
    assert(s.client:HasIngredients("cutstone") and s:build("cutstone") and s.spent == 0)
end)
test("normal materials remain required", function()
    local s = fixture(); s:tool("axe"); s.materials = 0
    assert(not s.server:HasIngredients("boards") and not s.client:HasIngredients("boards"))
    assert(not s:build("boards") and s.spent == 0)
end)
test("recipe-specific canbuild denial is preserved", function()
    local s = fixture(); s:tool("axe")
    recipes.boards.canbuild = function() return false, "OTHER_MOD_DENIAL" end
    local ok, reason = s:build("boards")
    recipes.boards.canbuild = nil
    assert(not ok and reason == "OTHER_MOD_DENIAL" and s.spent == 0)
end)
test("unrelated and transmutation recipes are untouched", function()
    local s = fixture()
    assert(s:build("rope") and s:build("transmute_cutstone"))
end)
test("configuration switches are independent", function()
    for _, axe in ipairs({ true, false }) do
        for _, chisel in ipairs({ true, false }) do
            for _, thirdparty in ipairs({ true, false }) do
                options.mam_axe_crafting, options.mam_chisel_crafting = axe, chisel
                options.mam_third_party_recipe_integration = thirdparty
                local s = fixture()
                assert(s.server:HasIngredients("boards") == not axe)
                assert(s.client:HasIngredients("cutstone") == not chisel)
            end
        end
    end
end)
test("wrappers preserve arguments nil returns and are idempotent", function()
    local s = fixture(); s:tool("axe")
    local builder = { inst = s.inst, HasIngredients = function(_, _, ...) return true, nil, ... end,
        DoBuild = function(_, _, ...) return true, nil, ... end }
    gate.WrapBuilder(builder, true)
    local first = builder.DoBuild; gate.WrapBuilder(builder, true); assert(first == builder.DoBuild)
    local ok, gap, a, b = builder:DoBuild("boards", "point", 40)
    assert(ok and gap == nil and a == "point" and b == 40)
    ok, gap, a = builder:HasIngredients("boards", "extra")
    assert(ok and gap == nil and a == "extra")
end)
test("axe gate preserves common board cost and Woodie forwarding metadata", function()
    local ingredient = { type = "log", amount = 4, atlas = "native" }
    local recipe = { name = "boards", product = "boards", ingredients = { ingredient }, numtogive = 1,
        level = {}, no_builder_tag = "cancarveboards", forward_ingredients = { "woodie_boards", "other" },
        description = "boards", canbuild = function() end }
    local level, fn = recipe.level, recipe.canbuild
    gate.ApplyBoardRecipe(recipe); gate.ApplyBoardRecipe(recipe)
    assert(ingredient.amount == 4 and recipe.level == level and recipe.canbuild == fn)
    assert(recipe.no_builder_tag == "cancarveboards")
    assert(#recipe.forward_ingredients == 2 and recipe.forward_ingredients[1] == "woodie_boards"
        and recipe.forward_ingredients[2] == "other")
    assert(recipe.description == "mam_axe_boards")
end)
test("Woodie's three-log Lucy skill recipe is never rewritten", function()
    local recipe = { name = "woodie_boards", product = "boards",
        ingredients = { { type = "lucy", amount = 0 }, { type = "log", amount = 3 } },
        builder_skill = "woodie_human_lucy_1", description = "boards" }
    gate.ApplyBoardRecipe(recipe)
    assert(recipe.ingredients[1].type == "lucy" and recipe.ingredients[1].amount == 0)
    assert(recipe.ingredients[2].type == "log" and recipe.ingredients[2].amount == 3)
    assert(recipe.builder_skill == "woodie_human_lucy_1" and recipe.description == "boards")
end)
test("third-party costs descriptions and restrictions are preserved", function()
    local recipe = { product = "boards", ingredients = { { type = "log", amount = 7 } }, numtogive = 1,
        description = "other_mod", no_builder_tag = "other_tag" }
    gate.ApplyBoardRecipe(recipe)
    assert(recipe.ingredients[1].amount == 7 and recipe.description == "other_mod" and recipe.no_builder_tag == "other_tag")
end)
test("disabled woodworking does not change vanilla costs", function()
    options.mam_axe_crafting = false
    local recipe = { product = "boards", ingredients = { { type = "log", amount = 4 } }, numtogive = 1 }
    gate.ApplyBoardRecipe(recipe); assert(recipe.ingredients[1].amount == 4)
end)
local function hud_fixture(s)
    local builder = s.client
    s.client.inst.replica.builder = builder
    function builder:GetTechTrees() return {} end
    function builder:GetTechTreesNoTemp() return {} end
    function builder:GetAllRecipeCraftingLimits() return {} end
    function builder:KnowsRecipe() return true end
    function builder:CanLearn() return true end
    local hud = { owner = builder.inst, valid_recipes = {}, needtoupdate = true, refreshes = 0,
        craftingmenu = { Refresh = function() end }, pinbar = { Refresh = function() end },
        RefreshCraftingHelpText = function() end }
    function hud:UpdateRecipes() self.needtoupdate = true; self.refreshes = self.refreshes + 1 end
    function hud:RebuildRecipes()
        for name, recipe in pairs(recipes) do
            self.valid_recipes[name] = { meta = { can_build = builder:IsBuildBuffered(name)
                or builder:IsFreeBuildMode() or builder:HasIngredients(recipe) } }
        end
    end
    function hud:OnUpdate()
        if self.needtoupdate then self:RebuildRecipes(); self.needtoupdate = false end
    end
    if native_hud then hud.RebuildRecipes, hud.OnUpdate = native_hud.RebuildRecipes, native_hud.OnUpdate end
    if gate.WrapCraftingHUD then gate.WrapCraftingHUD(hud) end
    return hud
end

test("crafting HUD follows missing acquired broken and repaired tools", function()
    local s = fixture(); local hud = hud_fixture(s)
    hud:OnUpdate(0.3); assert(not hud.valid_recipes.boards.meta.can_build)
    local axe = s:tool("axe"); hud:UpdateRecipes()
    hud:OnUpdate(0.3); assert(hud.valid_recipes.boards.meta.can_build, "menu stayed unavailable after acquiring axe")
    axe.tags.broken = true
    hud:OnUpdate(0.3); assert(not hud.valid_recipes.boards.meta.can_build, "menu allowed a broken axe")
    axe.tags.broken = nil
    hud:OnUpdate(0.3); assert(hud.valid_recipes.boards.meta.can_build)
    local count = hud.refreshes
    hud:OnUpdate(0.3); hud:OnUpdate(0.3); assert(hud.refreshes == count)
    s.inventory.itemslots = {}
    hud:OnUpdate(0.3); assert(not hud.valid_recipes.boards.meta.can_build)
    s:tool("chisel", "overflow")
    hud:OnUpdate(0.3); assert(hud.valid_recipes.cutstone.meta.can_build)
    s.inventory.overflow = nil
    hud:OnUpdate(0.3); assert(not hud.valid_recipes.cutstone.meta.can_build)
end)

test("crafting HUD cannot advertise a buffered build without its tool", function()
    local s = fixture(); s.buffer = true
    local hud = hud_fixture(s); hud:OnUpdate(0.3)
    assert(not hud.valid_recipes.boards.meta.can_build)
    s:tool("axe"); hud:OnUpdate(0.3); assert(hud.valid_recipes.boards.meta.can_build)
end)

test("unrelated open storage and nested containers cannot supply tools", function()
    local s = fixture(); local item = s:tool("axe"); s.inventory.itemslots = {}
    s.inventory.opencontainers = { [item] = true }; blocked(s, "boards")
    local bag = { slots = { item } }
    s.inventory.itemslots[1] = { components = { container = bag }, IsValid = function() return true end,
        HasTag = function() return false end }
    blocked(s, "boards")
end)

test("nearly worn out axe stays valid until its actual uses run out", function()
    local s = fixture(); s:tool("axe").components.finiteuses.current = 0.001
    assert(s.client:HasIngredients("boards") and s:build("boards"))
end)

test("repurposed recipe IDs do not inherit unrelated tool requirements", function()
    local recipe = { name = "boards", product = "other_mod_product" }
    assert(gate.CanCraft(fixture().server, recipe, true))
    recipe = { name = "cutstone", product = "other_mod_product" }
    assert(gate.CanCraft(fixture().client, recipe, false))
end)

test("HUD wrapper preserves returns arguments cadence and disabled state", function()
    local s = fixture()
    local hud = { owner = s.client.inst, refreshes = 0,
        UpdateRecipes = function(self) self.refreshes = self.refreshes + 1 end,
        OnUpdate = function(_, dt, ...) return dt, nil, ... end }
    gate.WrapCraftingHUD(hud)
    local first = hud.OnUpdate; gate.WrapCraftingHUD(hud); assert(first == hud.OnUpdate)
    local dt, gap, extra = hud:OnUpdate(0.01, "extra")
    assert(dt == 0.01 and gap == nil and extra == "extra")
    s:tool("axe"); hud:OnUpdate(0.01); assert(hud.refreshes == 1)
    hud:OnUpdate(0.3); assert(hud.refreshes == 2)
    options.mam_axe_crafting, options.mam_chisel_crafting = false, false
    hud = { OnUpdate = function() end }; first = hud.OnUpdate
    gate.WrapCraftingHUD(hud); assert(hud.OnUpdate == first)
end)

local function source(path)
    local f = assert(io.open(path, "r")); local text = f:read("*a"); f:close(); return text
end

if arg[1] then
    test("installed recipe declarations preserve costs skills stations and batch callbacks", function()
        local targets = { boards = true, woodie_boards = true, boards_bunch = true, cutstone = true, cutstone_bunch = true }
        local live = {}
        local tech = setmetatable({}, { __index = function(self, key)
            local value = { ORPHANAGE = 0 }; rawset(self, key, value); return value
        end })
        local recipe_env = { TECH = tech, Ingredient = function(name, amount) return { type = name, amount = amount } end,
            Recipe2 = function(name, ingredients, level, config)
                local recipe = config or {}; recipe.name = name; recipe.ingredients = ingredients; recipe.level = level
                recipe.product = recipe.product or name; recipe.numtogive = recipe.numtogive or 1
                live[name] = recipe
            end }
        for line in source(arg[1] .. "/recipes.lua"):gmatch("[^\r\n]+") do
            if targets[line:match('^Recipe2%("([^"]+)"')] then setfenv(assert(loadstring(line)), recipe_env)() end
        end
        for name in pairs(targets) do assert(live[name], name) end
        assert(live.boards.ingredients[1].amount == 4 and live.boards.level == tech.SCIENCE_ONE)
        assert(live.woodie_boards.ingredients[1].type == "lucy" and live.woodie_boards.ingredients[1].amount == 0)
        assert(live.woodie_boards.ingredients[2].type == "log" and live.woodie_boards.ingredients[2].amount == 3)
        assert(live.woodie_boards.builder_skill == "woodie_human_lucy_1" and live.woodie_boards.level == tech.NONE)
        gate.ApplyBoardRecipe(live.boards); gate.ApplyStoneRecipe(live.cutstone)
        assert(live.boards.ingredients[1].amount == live.woodie_boards.ingredients[2].amount)
        assert(live.boards.level == tech.SCIENCE_ONE and live.cutstone.level == tech.SCIENCE_ONE)
        assert(live.cutstone.ingredients[1].type == "rocks" and live.cutstone.ingredients[1].amount == 3)
        for _, name in ipairs({ "boards_bunch", "cutstone_bunch" }) do
            local recipe = live[name]
            assert(recipe.numtogive == 5 and recipe.station_tag == "carpentry_station" and recipe.nounlock)
            assert(recipe.ingredients[1].amount == (name == "boards_bunch" and 20 or 15))
            assert(recipe.level == (name == "boards_bunch" and tech.CARPENTRY_TWO or tech.CARPENTRY_THREE))
            local original = recipes[name]; recipes[name] = recipe
            recipe.character_ingredients, recipe.tech_ingredients = {}, {}
            local s = fixture(); s:tool(name == "boards_bunch" and "axe" or "chisel")
            s.server.current_prototyper = { AnimState = { IsCurrentAnimation = function(_, animation) return animation == "use" end } }
            local ok, reason = s:build(name)
            recipes[name] = original
            assert(not ok and reason == "BUSY_STATION" and s.spent == 0)
        end
    end)
end

for _, dedicated in ipairs({ false, true }) do
    test("modmain registers independent hooks and recipe; dedicated=" .. tostring(dedicated), function()
        local main = source(root .. "modmain.lua")
        local start = assert(main:find('local ToolCrafting = require("mam/tool_crafting")', 1, true))
        local finish = assert(main:find('modimport("initialise/modded_regrow.lua")', start, true))
        assert(main:find('MAMConfig.Init(GetModConfigData)', 1, true) < start)
        assert(main:find('"mam_stone_chisel",', 1, true))
        for _, axe in ipairs({ 0, 1 }) do
            for _, chisel in ipairs({ 0, 1 }) do
                local cfg = assert(loadfile(root .. "scripts/mam/config.lua"))()
                cfg.Init(function(key)
                    if key == "mam_axe_crafting" then return axe end
                    if key == "mam_chisel_crafting" then return chisel end
                    if key == "mam_third_party_recipe_integration" then return 0 end
                end)
                local module = setfenv(assert(loadfile(root .. "scripts/mam/tool_crafting.lua")),
                    setmetatable({ GLOBAL = globals, require = function() return cfg end }, { __index = _G }))()
                local live = {
                    boards = { name = "boards", product = "boards", numtogive = 1,
                        ingredients = { { type = "log", amount = 4 } } },
                    cutstone = { name = "cutstone", product = "cutstone" },
                }
                local hooks, late, created = {}, nil, nil
                local tech = {}
                local api = setmetatable({ GLOBAL = { TheNet = { IsDedicated = function() return dedicated end } },
                    AllRecipes = live, MAMConfig = cfg, TECH = { NONE = tech },
                    require = function(name) assert(name == "mam/tool_crafting"); return module end,
                    AddComponentPostInit = function(name, fn) hooks[name] = fn end,
                    AddClassPostConstruct = function(name, fn) hooks[name] = fn end,
                    AddRecipePostInit = function(name, fn) hooks[name] = fn; fn(live[name]) end,
                    AddSimPostInit = function(fn) late = fn end,
                    Ingredient = function(name, count) return { type = name, amount = count } end,
                    AddRecipe2 = function(name, ingredients, level, data, filters)
                        created = { name = name, ingredients = ingredients, level = level, data = data, filters = filters }
                    end,
                }, { __index = _G })
                setfenv(assert(loadstring(main:sub(start, finish - 1))), api)()
                assert(hooks.builder and hooks["components/builder_replica"])
                assert((hooks["widgets/redux/craftingmenu_hud"] ~= nil) == not dedicated)
                assert(live.boards.ingredients[1].amount == (axe == 1 and 3 or 4))
                assert((live.cutstone.description ~= nil) == (chisel == 1))
                assert((created ~= nil) == (chisel == 1))
                if created then
                    assert(created.name == "mam_stone_chisel" and created.level == tech)
                    assert(#created.ingredients == 2 and created.ingredients[1].type == "twigs"
                        and created.ingredients[1].amount == 2 and created.ingredients[2].type == "flint"
                        and created.ingredients[2].amount == 2)
                    assert(created.data.image == "pumpkincarver1.tex"
                        and created.filters[1] == "TOOLS" and created.filters[2] == "REFINE")
                end
                live.boards.ingredients[1].amount = 7; late(); late()
                assert(live.boards.ingredients[1].amount == 7)
                live.boards = { product = "boards", numtogive = 1, ingredients = { { type = "log", amount = 4 } } }
                late(); assert(live.boards.ingredients[1].amount == (axe == 1 and 3 or 4))
                local s = fixture()
                local server = { inst = s.inst, HasIngredients = function() return true end, DoBuild = function() return true end }
                hooks.builder(server); assert(server:DoBuild("boards") == (axe == 0))
                local replica = { inst = s.client.inst, HasIngredients = function() return true end,
                    IsBuildBuffered = function() return true end, IsFreeBuildMode = function() return false end }
                hooks["components/builder_replica"](replica)
                assert(replica:HasIngredients("cutstone") == (chisel == 0))
            end
        end
    end)
end

test("configuration declarations match validated defaults and reject malformed values", function()
    local modinfo = {}; setfenv(assert(loadfile(root .. "modinfo.lua")), setmetatable(modinfo, { __index = _G }))()
    local cfg = assert(loadfile(root .. "scripts/mam/config.lua"))()
    for _, key in ipairs({ "mam_axe_crafting", "mam_chisel_crafting" }) do
        cfg.Init()
        local option
        for _, entry in ipairs(modinfo.configuration_options) do if entry.name == key then option = entry end end
        assert(option and option.default == 1 and cfg.get(key) == 1)
        for _, value in ipairs({ -1, 2, "0", false }) do
            cfg.Init(function() return value end); assert(cfg.get(key) == 1)
        end
        cfg.Init(function() return 0 end); assert(not cfg.on(key))
    end
end)

for _, master in ipairs({ false, true }) do
    test("chisel prefab has reusable saveable inventory setup; master=" .. tostring(master), function()
        local inst = { components = {}, tags = {}, persists = true, AnimState = {}, entity = {} }
        for _, name in ipairs({ "AddTransform", "AddAnimState", "AddNetwork" }) do inst.entity[name] = function() end end
        function inst.entity:SetPristine() assert(inst.tags.mam_stone_chisel); inst.pristine = true end
        function inst.AnimState:SetBank(value) inst.bank = value end
        function inst.AnimState:SetBuild(value) inst.build = value end
        function inst.AnimState:PlayAnimation(value) inst.animation = value end
        function inst:AddTag(tag) assert(not self.pristine); self.tags[tag] = true end
        function inst:AddComponent(name)
            assert(master and self.pristine)
            assert(name == "inventoryitem" or name == "inspectable")
            self.components[name] = { ChangeImageName = function(_, image) inst.image = image end }
        end
        local prefab_env = setmetatable({ TheWorld = { ismastersim = master }, CreateEntity = function() return inst end,
            Asset = function(kind, path) return { kind = kind, path = path } end,
            MakeInventoryPhysics = function() end, MakeInventoryFloatable = function() end, MakeHauntableLaunch = function() end,
            Prefab = function(name, fn, assets) return { name = name, fn = fn, assets = assets } end,
        }, { __index = _G })
        local prefab = setfenv(assert(loadfile(root .. "scripts/prefabs/mam_stone_chisel.lua")), prefab_env)()
        assert(prefab.name == "mam_stone_chisel" and prefab.assets[1].path == "anim/pumpkincarver.zip")
        assert(prefab.fn() == inst and inst.pristine and inst.persists)
        assert(inst.bank == "pumpkincarver" and inst.build == "pumpkincarver" and inst.animation == "carver1")
        assert(not inst.components.finiteuses and not inst.components.stackable and not inst.components.pumpkincarver)
        assert((inst.components.inventoryitem ~= nil) == master)
        if master then assert(inst.image == "pumpkincarver1" and inst.components.inspectable) end
    end)
end

for _, locale in ipairs({ "ptbr", "en" }) do
    test("localized tool feedback loads without replacing native strings: " .. locale, function()
        local generic = { DESCRIBE = {}, ACTIONFAIL = { BUILD = { NATIVE_SENTINEL = "native" } } }
        if arg[1] then generic = assert(loadfile(arg[1] .. "/speech_wilson.lua"))() end
        local build = generic.ACTIONFAIL.BUILD
        local strings = { NAMES = {}, RECIPE_DESC = {}, CHARACTERS = { GENERIC = generic }, ACTIONS = { OPEN_CRAFTING = {} } }
        local globals = { STRINGS = strings, require = function() return { get = function() return locale end } end }
        setfenv(assert(loadfile(root .. "initialise/modded_strings.lua")), { GLOBAL = globals, pairs = pairs })()
        assert(generic.ACTIONFAIL.BUILD == build)
        assert(strings.NAMES.MAM_STONE_CHISEL == (locale == "en" and "Stone-Carving Chisel" or "Cinzel de Entalhe em Pedra"))
        assert(build.MAM_NEEDS_AXE and build.MAM_NEEDS_CHISEL and strings.RECIPE_DESC.MAM_AXE_BOARDS)
    end)
end

print(string.format("Tool-gated crafting (%s): %d passed / %d failed", native and "local DST methods, stub entities" or "stubs", passed, failed))
assert(failed == 0, "tool crafting regressions")
