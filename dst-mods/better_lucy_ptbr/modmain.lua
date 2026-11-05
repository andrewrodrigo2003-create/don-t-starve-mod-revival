local G = GLOBAL

local DAMAGE_MULT = GetModConfigData("DAMAGE_MULT") or 2.0
local CHOP_POWER = GetModConfigData("CHOP_POWER") or 4
local VOICE_MODE = GetModConfigData("VOICE_MODE") or "quiet"
local DIALOGUE_MODE = GetModConfigData("DIALOGUE_MODE") or "mixed"
local SPEECH_DURATION = GetModConfigData("SPEECH_DURATION") or 3.25
local PERSONALITY = GetModConfigData("PERSONALITY") or "all"
local WOODIE_REPLY_CHANCE = GetModConfigData("WOODIE_REPLY")
if type(WOODIE_REPLY_CHANCE) ~= "number" then
    WOODIE_REPLY_CHANCE = 0.25
end

-- Minimum seconds between two Woodie replies (keeps it "de vez em quando").
local WOODIE_REPLY_COOLDOWN = 40
-- Woodie only answers if he is this close to Lucy (same as vanilla Lucy talk range).
local WOODIE_REPLY_RANGE = 15

local PROFILES = require("better_lucy_lines")
local REPLY_PROFILES = require("better_lucy_woodie_replies")

local function copy_table(src)
    local dst = {}
    if src ~= nil then
        for i, v in ipairs(src) do
            dst[i] = v
        end
    end
    return dst
end

local function append_unique(dst, src)
    if dst == nil or src == nil then
        return
    end

    local seen = {}
    for _, line in ipairs(dst) do
        seen[line] = true
    end

    for _, line in ipairs(src) do
        if not seen[line] then
            table.insert(dst, line)
            seen[line] = true
        end
    end
end

local function sorted_keys(t)
    local keys = {}
    for k in pairs(t) do
        table.insert(keys, k)
    end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    return keys
end

local ORDER = { "classic", "wife", "yandere", "spicy" }
local LIMIT =
{
    classic = 1,
    wife = 2,
    yandere = 3,
    spicy = 4,
    all = 4,
}

local maxprofile = LIMIT[PERSONALITY] or 4

local function merge_profiles(profiles)
    local merged = {}
    for i = 1, maxprofile do
        local profile = profiles[ORDER[i]]
        if profile ~= nil then
            -- Sorted so every machine (server and clients) builds identical tables.
            for _, category in ipairs(sorted_keys(profile)) do
                merged[category] = merged[category] or {}
                append_unique(merged[category], profile[category])
            end
        end
    end
    return merged
end

local merged = merge_profiles(PROFILES)

G.STRINGS.LUCY = G.STRINGS.LUCY or {}

if DIALOGUE_MODE ~= "vanilla" then
    for _, category in ipairs(sorted_keys(merged)) do
        local custom_lines = merged[category]
        if DIALOGUE_MODE == "custom" then
            G.STRINGS.LUCY[category] = copy_table(custom_lines)
        else
            if type(G.STRINGS.LUCY[category]) ~= "table" then
                G.STRINGS.LUCY[category] = {}
            end
            append_unique(G.STRINGS.LUCY[category], custom_lines)
        end
    end
end

--------------------------------------------------------------------------
-- FIX: Lucy's line number is sent over the network in a "smallbyte"
-- (values 0..63). Lists with more than 63 lines made Lucy say the wrong
-- line or nothing at all. Big lists are split into extra hidden lists of
-- up to 63 lines, and the chosen line is sent from the right piece.
--------------------------------------------------------------------------

local MAX_NET_LINES = 63
local CHUNKS = {}       -- [full list table] = { chunk1, chunk2, ... }
local CATEGORY_OF = {}  -- [list table] = category name

for _, category in ipairs(sorted_keys(G.STRINGS.LUCY)) do
    local list = G.STRINGS.LUCY[category]
    if type(list) == "table" then
        CATEGORY_OF[list] = category
        if #list > MAX_NET_LINES then
            local chunks = {}
            local n = math.ceil(#list / MAX_NET_LINES)
            for c = 1, n do
                local chunk = {}
                for i = (c - 1) * MAX_NET_LINES + 1, math.min(c * MAX_NET_LINES, #list) do
                    table.insert(chunk, list[i])
                end
                local key = "betterlucy_" .. category .. "_" .. c
                G.STRINGS.LUCY[key] = chunk
                CATEGORY_OF[chunk] = category
                chunks[c] = chunk
            end
            CHUNKS[list] = chunks
        end
    end
end

--------------------------------------------------------------------------
-- Woodie replies
--------------------------------------------------------------------------

local REPLY_POOLS = {}
do
    local replies = merge_profiles(REPLY_PROFILES)
    local any = replies.any or {}
    for _, category in ipairs(sorted_keys(G.STRINGS.LUCY)) do
        local pool = copy_table(replies[category])
        append_unique(pool, any)
        REPLY_POOLS[category] = pool
    end
end

-- Lucy situations where Woodie should never answer.
local NO_REPLY =
{
    on_haunt = true,                 -- Woodie is a ghost
    transform_beaver = true,         -- Woodie is turning into a beaver
    on_woodie_pickedup_other = true, -- talking to another axe
}

local last_reply_time = setmetatable({}, { __mode = "k" })

local function CanWoodieTalk(owner)
    return owner ~= nil
        and owner:IsValid()
        and owner.components.talker ~= nil
        and not owner:HasTag("playerghost")
        and not owner:HasTag("wereplayer")
        and not (owner.components.health ~= nil and owner.components.health:IsDead())
        and not (owner.sg ~= nil and owner.sg:HasStateTag("transform"))
end

local function DoWoodieReply(owner, axe, line)
    if not CanWoodieTalk(owner) or axe == nil or not axe:IsValid() then
        return
    end
    if not owner:IsNear(axe, WOODIE_REPLY_RANGE) then
        return
    end
    -- Don't interrupt something Woodie is already saying.
    if owner.components.talker.task ~= nil then
        return
    end
    owner.components.talker:Say(line)
end

local function TryWoodieReply(sentientaxe, list)
    if WOODIE_REPLY_CHANCE <= 0 or not G.TheWorld.ismastersim then
        return
    end

    local owner = sentientaxe.owner
    local category = CATEGORY_OF[list]
    if category == nil or NO_REPLY[category] or not CanWoodieTalk(owner) then
        return
    end

    local pool = REPLY_POOLS[category]
    if pool == nil or #pool == 0 then
        return
    end

    local now = G.GetTime()
    if last_reply_time[owner] ~= nil and now - last_reply_time[owner] < WOODIE_REPLY_COOLDOWN then
        return
    end
    if math.random() > WOODIE_REPLY_CHANCE then
        return
    end

    last_reply_time[owner] = now
    local line = pool[math.random(#pool)]
    local delay = math.min(SPEECH_DURATION, 4) * 0.6 + math.random() * 0.8
    owner:DoTaskInTime(delay, function() DoWoodieReply(owner, sentientaxe.inst, line) end)
end

--------------------------------------------------------------------------
-- SentientAxe:Say wrapper (server side). Keeps vanilla behaviour for small
-- lists, uses the split lists for big ones, and adds Woodie's replies.
--------------------------------------------------------------------------

local SentientAxe = G.require("components/sentientaxe")
local _SentientAxe_Say = SentientAxe.Say

function SentientAxe:Say(list, sound_override, delay, ...)
    -- Delayed speech is re-sent through this same function later.
    if delay ~= nil or type(list) ~= "table" then
        return _SentientAxe_Say(self, list, sound_override, delay, ...)
    end

    -- Vanilla would crash on math.random(0) with an empty list.
    if #list == 0 then
        return
    end

    local chunks = CHUNKS[list]
    if chunks == nil then
        _SentientAxe_Say(self, list, sound_override, delay, ...)
    else
        if self.say_task ~= nil then
            self.say_task:Cancel()
            self.say_task = nil
        end

        local i = math.random(#list)
        local chunk = chunks[math.ceil(i / MAX_NET_LINES)]
        local index = (i - 1) % MAX_NET_LINES + 1

        if self.inst.lucy_classified ~= nil then
            self.inst.lucy_classified:Say(chunk, index, sound_override)
        end
        if self.owner ~= nil then
            self:ScheduleConversation(60 + math.random() * 60)
        end
    end

    TryWoodieReply(self, list)
end

--------------------------------------------------------------------------
-- Lucy prefab tweaks
--------------------------------------------------------------------------

local VOLUME =
{
    normal = 1.0,
    quiet = 0.50,
    veryquiet = 0.25,
    muted = 0.0,
}

local target_volume = VOLUME[VOICE_MODE] or 0.50

AddPrefabPostInit("lucy", function(inst)
    -- FIX: Lucy's speech bubble is shown by each player's own game, so the
    -- display time must be set everywhere, not only on the server.
    if inst.components.talker ~= nil then
        inst.components.talker.lineduration = SPEECH_DURATION
    end

    -- Gameplay upgrades (server-side).
    if G.TheWorld ~= nil and G.TheWorld.ismastersim then
        if inst.components.weapon ~= nil then
            local base_damage = inst.components.weapon.damage
            if type(base_damage) == "number" then
                inst.components.weapon:SetDamage(base_damage * DAMAGE_MULT)
            end
        end

        if inst.components.tool ~= nil then
            inst.components.tool:SetAction(G.ACTIONS.CHOP, CHOP_POWER)
        end
    end

    -- Normal mode leaves Klei's original Lucy audio completely untouched.
    if VOICE_MODE == "normal" then
        return
    end

    -- Lucy's chatter is played on a local-only sound entity
    -- (inst.localsounds.SoundEmitter). We play it ourselves at the chosen
    -- volume and stop the vanilla full-volume "ontalk" handler.
    local original_PushEvent = inst.PushEvent

    inst.PushEvent = function(self, event, data, ...)
        if event == "ontalk" then
            if target_volume > 0
                and self.localsounds ~= nil
                and self.localsounds.SoundEmitter ~= nil then

                local emitter = self.localsounds.SoundEmitter
                local sound =
                    self.lucy_classified ~= nil
                    and self.lucy_classified.GetTalkSound ~= nil
                    and self.lucy_classified:GetTalkSound()
                    or nil

                emitter:KillSound("talk")
                emitter:PlaySound(sound or "dontstarve/characters/woodie/lucytalk_LP", "talk", target_volume)
            end
            return
        end

        return original_PushEvent(self, event, data, ...)
    end

    inst:ListenForEvent("donetalking", function()
        if inst.localsounds ~= nil and inst.localsounds.SoundEmitter ~= nil then
            inst.localsounds.SoundEmitter:KillSound("talk")
        end
    end)
end)
