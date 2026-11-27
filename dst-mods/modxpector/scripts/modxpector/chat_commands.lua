local M = {}
local function trim(value)
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end
local function safe_identifier(value)
    return type(value) == "string" and #value >= 1 and #value <= 64
        and value:match("^[%w_%-]+$") ~= nil
end
function M.Parse(message)
    if type(message) ~= "string" or #message > 256 then return nil, "invalid_message" end
    local text = trim(message)
    local prefix, command_text = text:match("^([/!][%w_]+)%s*(.*)$")
    if prefix == nil then return nil, "not_a_modxpector_command" end
    prefix = prefix:lower()
    if prefix ~= "/mx" and prefix ~= "!mx" then return nil, "not_a_modxpector_command" end
    local tokens = {}
    for token in command_text:gmatch("%S+") do
        if #tokens >= 4 then return { kind = "invalid", reason = "too_many_arguments" } end
        tokens[#tokens + 1] = token
    end
    if #tokens == 0 then return { kind = "help" } end
    local command = tokens[1]:lower()
    if command == "analisar" and (#tokens == 1 or (#tokens == 2 and tokens[2]:lower() == "mods")) then
        return { kind = "analyze" }
    elseif command == "status" and #tokens == 1 then
        return { kind = "status" }
    elseif command == "parar" and #tokens == 1 then
        return { kind = "stop" }
    elseif command == "ajuda" and #tokens == 1 then
        return { kind = "help" }
    elseif command == "testar" and #tokens == 1 then
        return { kind = "list_suites" }
    elseif command == "testar" and #tokens == 3 then
        if not safe_identifier(tokens[2]) or not safe_identifier(tokens[3]) then
            return { kind = "invalid", reason = "invalid_suite_or_scenario_id" }
        end
        return { kind = "run_suite", suite_id = tokens[2], scenario_id = tokens[3] }
    end
    return { kind = "invalid", reason = "unsupported_command" }
end
return M
