-- Stategraph callback wrappers for MAM spell/cast states.
-- Preserve vanilla callback arguments and return values, and always run onexit.
local M = {}

function M.WrapCastState(state, target_time, get_equipped_item)
    if type(state) ~= "table" then
        return false
    end

    local old_onenter = state.onenter
    local old_onexit = state.onexit
    local old_onupdate = state.onupdate

    state.onenter = function(inst, ...)
        local statemem = inst.sg ~= nil and inst.sg.statemem or nil
        if statemem ~= nil then
            statemem.tm = 0
            statemem.trgt = target_time
            statemem.equip = get_equipped_item ~= nil and get_equipped_item(inst) or nil
        end

        if old_onenter ~= nil then
            return old_onenter(inst, ...)
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
