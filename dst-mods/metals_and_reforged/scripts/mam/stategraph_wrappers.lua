-- Stategraph callback wrappers for MAM spell/cast states.
-- Preserve vanilla callback arguments and return values, and always run onexit.
local M = {}
local unpack = unpack

local function pack(...)
    return { n = select("#", ...), ... }
end

local function unpack_results(results)
    return unpack(results, 1, results.n)
end

function M.WrapCastState(state, target_time, get_equipped_item)
    if type(state) ~= "table" or state.mam_cast_wrapper then
        return false
    end

    state.mam_cast_wrapper = true

    local old_onenter = state.onenter
    local old_onexit = state.onexit
    local old_onupdate = state.onupdate

    state.onenter = function(inst, ...)
        local statemem = inst ~= nil and inst.sg ~= nil and inst.sg.statemem or nil
        local equipped_ok, equipped = true, nil
        if type(get_equipped_item) == "function" then
            equipped_ok, equipped = pcall(get_equipped_item, inst)
        end

        if statemem ~= nil then
            statemem.tm = 0
            statemem.trgt = target_time
            statemem.equip = equipped_ok and equipped or nil
        end

        local results
        if old_onenter ~= nil then
            results = pack(old_onenter(inst, ...))
        end
        if not equipped_ok then
            error(equipped, 0)
        end
        if results ~= nil then
            return unpack_results(results)
        end
    end

    state.onexit = function(inst, ...)
        local statemem = inst.sg ~= nil and inst.sg.statemem or nil
        local equip = statemem ~= nil and statemem.equip or nil
        if equip ~= nil and statemem.tm ~= nil and statemem.trgt ~= nil
            and statemem.tm < statemem.trgt then
            local components = equip.components
            local reticule = components ~= nil and components.reticule_spawner or nil
            if reticule ~= nil and reticule.Interrupt ~= nil then
                -- A third-party reticule hook must not prevent vanilla state cleanup.
                -- Preserve the error after onexit so the underlying compatibility
                -- problem remains visible instead of silently swallowing it.
                local interrupt_ok, interrupt_err = pcall(reticule.Interrupt, reticule)
                if not interrupt_ok then
                    if old_onexit ~= nil then
                        old_onexit(inst, ...)
                    end
                    error(interrupt_err, 0)
                end
            end
        end

        -- Never skip vanilla cleanup just because the player had no equipped item.
        if old_onexit ~= nil then
            return old_onexit(inst, ...)
        end
    end

    state.onupdate = function(inst, dt, ...)
        local statemem = inst.sg ~= nil and inst.sg.statemem or nil
        if statemem ~= nil then
            statemem.tm = (statemem.tm or 0) + (dt or 0)
        end

        if old_onupdate ~= nil then
            return old_onupdate(inst, dt, ...)
        end
    end

    return true
end

return M
