-- Minimal DST-like environment to exercise Better Lucy modmain
package.path = "/dev-server/dst-mods/better_lucy_ptbr/scripts/?.lua;/tmp/game/scripts/?.lua;" .. package.path
function Class(ctor) local c = {}; c.__index = c; setmetatable(c, {__call=function(_, ...) local o=setmetatable({},c); ctor(o, ...); return o end}); return c end
local src = io.open("/tmp/game/scripts/strings.lua"):read("*a")
STRINGS = {}
loadstring(src:match("(STRINGS%.LUCY%s*=%s*%b{})"))()
local now = 0
GetTime = function() return now end
TheWorld = { ismastersim = true }
ACTIONS = { CHOP = "CHOP" }
TUNING = { LUCY_CARVING_TALK_COOLDOWN = 1 }
FRAMES = 1/30
local CONFIG = { WOODIE_REPLY = tonumber(arg[1]) or 1, PERSONALITY = arg[2] or "all", DIALOGUE_MODE = arg[3] or "mixed" }
local env = setmetatable({ GLOBAL = _G, require = require, GetModConfigData = function(k) return CONFIG[k] end,
  AddPrefabPostInit = function() end }, { __index = _G })
local f = assert(loadfile("/dev-server/dst-mods/better_lucy_ptbr/modmain.lua")); setfenv(f, env); f()
local STRING_LISTS = {}
for k, v in pairs(STRINGS.LUCY) do table.insert(STRING_LISTS, v) end
local IDS = {} for i, v in ipairs(STRING_LISTS) do IDS[v] = i end
assert(#STRING_LISTS <= 63, "too many lists for smallbyte: "..#STRING_LISTS)
local shown, bad = {}, 0
local classified = { Say = function(_, list, id)
  local lid = IDS[list]; assert(lid, "list not registered")
  local s = STRING_LISTS[lid][id % 64]
  if s == nil then bad = bad + 1 else shown[s] = true end
end }
local tasks, woodie_said = {}, {}
local owner = { IsValid=function() return true end, HasTag=function() return false end, IsNear=function() return true end,
  components = { talker = { Say = function(_, l) table.insert(woodie_said, l) end } },
  DoTaskInTime = function(_, d, fn) table.insert(tasks, fn) end }
local axe = { lucy_classified = classified, IsValid=function() return true end, DoTaskInTime=function() return {Cancel=function() end} end }
local SentientAxe = require("components/sentientaxe")
local comp = setmetatable({ inst = axe, owner = owner, ScheduleConversation = function() end }, SentientAxe)
math.randomseed(1)
for _, cat in ipairs({"equipped","on_chopped","other_owner","on_ground"}) do
  shown, bad = {}, 0
  for i = 1, 20000 do comp:Say(STRINGS.LUCY[cat]); now = now + 50 end
  local uniq = 0 for _ in pairs(shown) do uniq = uniq + 1 end
  print(cat, "lines:", #STRINGS.LUCY[cat], "distinct shown:", uniq, "broken:", bad)
  assert(bad == 0 and uniq == #STRINGS.LUCY[cat], "FAIL "..cat)
end
for _, fn in ipairs(tasks) do fn() end
print("lists:", #STRING_LISTS, "woodie replies:", #woodie_said, "example:", woodie_said[1])
