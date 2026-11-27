local function new_strings()
    return {
        NAMES = {},
        RECIPE_DESC = {},
        ACTIONS = { OPEN_CRAFTING = {} },
        CHARACTERS = {
            GENERIC = {
                DESCRIBE = {},
                ACTIONFAIL = { BUILD = {} },
            },
            WENDY = { DESCRIBE = {} },
        },
    }
end

local original_global = GLOBAL
local original_strings = STRINGS

local function load_locale(language)
    local strings = new_strings()
    GLOBAL = {
        STRINGS = strings,
        require = function(name)
            assert(name == "mam/config")
            return {
                get = function(key, default)
                    assert(key == "mam_language")
                    return language or default
                end,
            }
        end,
    }
    STRINGS = strings
    dofile("dst-mods/metals_and_reforged/initialise/modded_strings.lua")
    return strings
end

local pt = load_locale("ptbr")
assert(pt.NAMES.COPPER_DUST == "Pó de cobre")
assert(pt.NAMES.DST_WILLOWDOLL == "Boneca da Willow")
assert(pt.NAMES.METALLURGY_REFERENCE_BOOK == "Guia de Metalurgia")
assert(pt.CHARACTERS.GENERIC.DESCRIBE.DST_WILLOWDOLL == "Só de olhar já sinto calor!")
assert(pt.CHARACTERS.WENDY.DESCRIBE.FORKSTICK == "Quem o forjou já se foi há muito tempo.")
assert(pt.RECIPE_DESC.FORGINGHAMMER == "Martelo de Forja do evento The Forge, temporada 1.")
assert(pt.CURSED_PIGGY_TALK_FIGHT[1] == "VOU MATAR AGORA!")

local en = load_locale("en")
assert(en.NAMES.COPPER_DUST == "Copper Dust")
assert(en.NAMES.DST_WILLOWDOLL == "Willow Doll")
assert(en.NAMES.METALLURGY_REFERENCE_BOOK == "Metallurgy Guide")
assert(en.CHARACTERS.GENERIC.DESCRIBE.DST_WILLOWDOLL == "I feel warm just looking at it!")
assert(en.CHARACTERS.WENDY.DESCRIBE.FORKSTICK == "Those who forged this are long gone.")
assert(en.RECIPE_DESC.FORGINGHAMMER == "Forging Hammer from The Forge Event, Season 1.")
assert(en.CURSED_PIGGY_TALK_FIGHT[1] == "I'LL KILL NOW!")

GLOBAL = original_global
STRINGS = original_strings

io.write("MAM localization runtime: PT-BR and English passed\n")
