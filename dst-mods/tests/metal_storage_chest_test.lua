-- Isolated prefab harness for Metal Storage Chest.
-- Run from the repository root with: texlua --luaonly dst-mods/tests/metal_storage_chest_test.lua
-- This stubs DST APIs; it does not replace an in-game or multiplayer test.

package.path = "dst-mods/metals_and_reforged/scripts/?.lua;" .. package.path
package.preload["prefabutil"] = function() return {} end
package.preload["tuning"] = function() return {} end

local function noop() end
ACTIONS = { HAMMER = "HAMMER" }
Asset = function(kind, path) return { kind = kind, path = path } end
MakeSnowCoveredPristine = noop
MakeSnowCovered = noop
AddHauntableDropItemOrWork = noop

local captured = {}
Prefab = function(name, fn, assets, prefabs)
    captured.name, captured.fn, captured.assets, captured.prefabs = name, fn, assets, prefabs
    return { name = name }, { kind = "prefab" }
end
MakePlacer = function(...)
    captured.placer = { ... }
    return { kind = "placer" }
end

local function build_instance(is_master)
    TheWorld = { ismastersim = is_master }
    local tags, spawned = {}, {}
    local removed = false
    local anim_calls, sound_calls = {}, {}

    local function make_component(name)
        if name == "container" then
            return {
                WidgetSetup = function(self, widget) self.widget = widget end,
                Close = function(self) self.closed = true end,
                DropEverything = function(self) self.dropped = true end,
            }
        elseif name == "lootdropper" then
            return { DropLoot = function(self) self.dropped_loot = true end }
        elseif name == "workable" then
            return {
                SetWorkAction = function(self, value) self.action = value end,
                SetWorkLeft = function(self, value) self.work = value end,
                SetOnFinishCallback = function(self, callback) self.finish = callback end,
                SetOnWorkCallback = function(self, callback) self.onwork = callback end,
            }
        end
        return {}
    end

    SpawnPrefab = function(name)
        local fx = {
            name = name,
            Transform = { SetPosition = function(self, ...) self.position = { ... } end },
            SetMaterial = function(self, material) self.material = material end,
        }
        table.insert(spawned, fx)
        return fx
    end

    CreateEntity = function()
        local inst = {
            components = {},
            Transform = { GetWorldPosition = function() return 1, 2, 3 end },
            AnimState = {
                SetBank = noop,
                SetBuild = noop,
                PlayAnimation = function(self, animation) table.insert(anim_calls, animation) end,
                PushAnimation = function(self, animation) table.insert(anim_calls, animation) end,
            },
            SoundEmitter = { PlaySound = function(self, sound) table.insert(sound_calls, sound) end },
            MiniMapEntity = { SetIcon = function(self, icon) self.icon = icon end },
            entity = {
                AddTransform = noop, AddAnimState = noop, AddSoundEmitter = noop,
                AddMiniMapEntity = noop, AddNetwork = noop, SetPristine = noop,
            },
            AddTag = function(self, tag) tags[tag] = true end,
            AddComponent = function(self, name) self.components[name] = make_component(name) end,
            ListenForEvent = noop,
            Remove = function(self) removed = true end,
        }
        return inst
    end

    local inst = captured.fn()
    return inst, tags, spawned, anim_calls, sound_calls, function() return removed end
end

local prefab, placer = dofile("dst-mods/metals_and_reforged/scripts/prefabs/metal_storage_chest.lua")
assert(captured.name == "metal_storage_chest", "wrong prefab name")
assert(#captured.assets == 2, "expected safe and 5x5 UI assets")
assert(captured.prefabs[1] == "collapse_small", "collapse prefab missing")
assert(placer ~= nil and captured.placer[1] == "metal_storage_chest_placer", "placer missing")

-- Server-side construction and normal-hit behavior.
local inst, tags, spawned = build_instance(true)
assert(tags.structure and tags.chest and tags.mam_metal_storage, "structure/chest/custom tags missing")
assert(inst.components.container.widget == "metal_storage_chest", "container widget not registered")
assert(inst.components.workable.action == ACTIONS.HAMMER and inst.components.workable.work == 3, "hammer setup incorrect")
assert(type(inst.components.container.onopenfn) == "function", "open callback missing")
assert(type(inst.components.container.onclosefn) == "function", "close callback missing")

inst.components.container.onopenfn(inst)
inst.components.container.onclosefn(inst)
assert(inst.components.container.closed == nil, "close animation callback should not itself close container")

inst.components.workable.onwork(inst, {})
assert(inst.components.container.closed, "ordinary hit should close container")
assert(not inst.components.container.dropped, "ordinary hit must not spill contents")

-- Destruction must drop stored contents and the collapse effect.
inst.components.workable.finish(inst, {})
assert(inst.components.lootdropper.dropped_loot, "lootdropper should run")
assert(inst.components.container.dropped, "hammer destruction must spill contents")
assert(#spawned == 1 and spawned[1].name == "collapse_small", "collapse effect missing")
assert(spawned[1].material == "metal", "collapse effect material incorrect")

-- Client replica must not receive server-only gameplay components.
local client_inst, client_tags = build_instance(false)
assert(client_tags.chest and client_tags.mam_metal_storage, "client replica tags missing")
assert(client_inst.components.container == nil and client_inst.components.workable == nil,
    "server-only components were added on client")

-- Exercise the exact filter factory used by modmain.lua with the real smelter
-- ingredient registry, not a duplicated allowlist.
local Smelting = require("smelting")
local MetalStorage = require("mam/metal_storage")
local itemtestfn = MetalStorage.MakeItemTestFn(Smelting.IsSmelterIngredient, Smelting.recipes.metal_smelter)
local registered_ingredients = 0
for prefab in pairs(Smelting.smelteringredients) do
    assert(itemtestfn(nil, { prefab = prefab }, nil),
        "registered smelter ingredient rejected by chest: " .. prefab)
    registered_ingredients = registered_ingredients + 1
end
assert(registered_ingredients > 0, "smelter ingredient registry unexpectedly empty")

-- Every registered metal output/product must also be storable.
local registered_products = 0
for prefab in pairs(Smelting.recipes.metal_smelter) do
    assert(itemtestfn(nil, { prefab = prefab }, nil),
        "registered smelter product rejected by chest: " .. prefab)
    registered_products = registered_products + 1
end
assert(registered_products > 0, "smelter product registry unexpectedly empty")

for _, prefab in ipairs({
    "log", "twigs", "cutgrass", "gears", "goldnugget_fake", "unknown_metal"
}) do
    assert(not itemtestfn(nil, { prefab = prefab }, nil),
        "non-ingredient accepted by chest: " .. prefab)
end
assert(not itemtestfn(nil, nil, nil), "nil item must be rejected")
assert(not itemtestfn(nil, {}, nil), "item without prefab must be rejected")
assert(not itemtestfn(nil, { prefab = 123 }, nil), "non-string prefab must be rejected")

-- Guard the production wiring: modmain must use the same tested factory and
-- the actual smelting predicate, rather than an independent filter.
local modmain = assert(io.open("dst-mods/metals_and_reforged/modmain.lua", "r"))
local modmain_source = modmain:read("*a")
modmain:close()
assert(modmain_source:find(
    'MAMMetalStorage.MakeItemTestFn(MAMSmelting.IsSmelterIngredient, MAMSmelting.recipes.metal_smelter)', 1, true
), "modmain is not wired to the tested chest filter")

print(("PASS: prefab lifecycle + %d registered ingredients + %d registered products accepted, invalid items rejected, production filter wiring verified")
    :format(registered_ingredients, registered_products))
