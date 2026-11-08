-- Resolve stack acceptance from the server-published smelter config.
-- The local option is only a fallback before the first config netvar arrives.
local M = {}

function M.accepts_stacks(inst, fallback)
    if inst == nil or inst.mam_plan == nil then
        return fallback
    end

    local netvar = inst.mam_plan
    if type(netvar.value) ~= "function" then
        return fallback
    end

    local ok, raw = pcall(netvar.value, netvar)
    if not ok or type(raw) ~= "string" then
        return fallback
    end

    local batch = string.match(raw, "^c|([01])|%d+|%d+")
    if batch == nil then
        return fallback
    end

    return batch == "1"
end

-- A netvar can arrive after the replica's first WidgetSetup call. Refresh only
-- when the server's published batch setting actually differs from the widget.
function M.needs_widget_refresh(inst, container)
    if container == nil then
        return false
    end
    return M.accepts_stacks(inst, container.acceptsstacks)
        ~= container.acceptsstacks
end

return M
