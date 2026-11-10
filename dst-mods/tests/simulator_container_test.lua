-- Shared simulator container/inventory contract test.
package.path = "dst-mods/tests/?.lua;dst-mods/tests/?/init.lua;" .. package.path
local Simulator = require("simulator.bootstrap")
local Item = require("simulator.core.item")
local Container = require("simulator.core.container")

local owner = Simulator.Entity.new("test_container")
local container = Container.new(owner, 3)
local events = { get = 0, lose = 0, open = 0, close = 0 }
container:ListenForEvent("itemget", function() events.get = events.get + 1 end)
container:ListenForEvent("itemlose", function() events.lose = events.lose + 1 end)
container:ListenForEvent("onopen", function() events.open = events.open + 1 end)
container:ListenForEvent("onclose", function() events.close = events.close + 1 end)

local copper = Item.new("copper_ore", 30, 40)
assert(container:GiveItem(copper, 1))
assert(container:GetItemInSlot(1) == copper)
assert(container:CountItems("copper_ore") == 30)

local more_copper = Item.new("copper_ore", 15, 40)
assert(container:GiveItem(more_copper))
assert(copper:StackSize() == 40)
assert(more_copper:IsValid() and more_copper:StackSize() == 5)
assert(container:CountItems("copper_ore") == 45)

local iron = Item.new("iron_ore", 4, 40)
assert(container:GiveItem(iron))
assert(container:GetItemInSlot(3) == iron)
assert(not container:GiveItem(Item.new("gold_ore", 1, 40)))
assert(not container:GiveItem(Item.new("invalid_slot_item", 1, 40), 4))

local player = {}
assert(container:Open(player))
assert(not container:Open(player), "same opener must not open twice")
assert(container:Close(player))
assert(not container:Close(player), "closed opener must not close twice")
assert(events.open == 1 and events.close == 1)

local removed = container:RemoveItemBySlot(3)
assert(removed == iron and container:GetItemInSlot(2) == nil)
assert(events.lose == 1)
local dropped = container:DropEverything()
assert(#dropped == 2 and dropped[1] == copper and dropped[2] == more_copper)
assert(container:CountItems() == 0)
assert(events.get == 4 and events.lose == 3)

print("DST simulator container: inventory/stack/open-close contracts passed")
