-- Metals and More - Reworked & Fixed
-- Log estruturado e execucoes protegidas.
--
-- Objetivo: nenhum hook nosso pode derrubar o carregamento do mod nem o de outro mod.
-- Todo ponto de extensao critico passa por MAMLog.Try / MAMLog.Guarded.
--
-- ATENCAO: DST usa Lua 5.1. xpcall NAO aceita argumentos extras e nao existe
-- table.unpack garantido. Este modulo abstrai essas diferencas.

local GLOBAL = rawget(_G, "GLOBAL") or _G

local MODNAME = "Metals and More R&F"
local unpack_fn = table.unpack or unpack

local MAMLog = {}

MAMLog.verbosity = 1 -- 0 silencioso, 1 avisos+erros, 2 tudo

local function stamp(tag)
    return "[" .. MODNAME .. "][" .. tag .. "] "
end

local function format(msg, ...)
    if select("#", ...) > 0 then
        local ok, out = pcall(string.format, tostring(msg), ...)
        if ok then
            return out
        end
    end
    return tostring(msg)
end

function MAMLog.Error(msg, ...)
    local text = stamp("ERRO") .. format(msg, ...)
    print(text)
    if GLOBAL.TheNet ~= nil and GLOBAL.TheNet.IsServerLoggingEnabled ~= nil
        and GLOBAL.TheNet:GetIsServerLoggingEnabled() then
        GLOBAL.TheNet:ServerLogMessage(text)
    end
end

function MAMLog.Warn(msg, ...)
    if MAMLog.verbosity >= 1 then
        print(stamp("AVISO") .. format(msg, ...))
    end
end

function MAMLog.Info(msg, ...)
    if MAMLog.verbosity >= 2 then
        print(stamp("INFO") .. format(msg, ...))
    end
end

--- Registra uma vez por chave; evita spam em callbacks periodicos.
local seen = {}
function MAMLog.WarnOnce(key, msg, ...)
    if seen[key] then
        return
    end
    seen[key] = true
    MAMLog.Warn(msg, ...)
end

--- Executa fn protegida. Retorna (ok, resultado) ou (false, erro).
function MAMLog.Try(where, fn, ...)
    local args = { ... }
    local result = nil
    local ok, err = xpcall(function()
        result = fn(unpack_fn(args))
    end, function(e)
        return debug.traceback(tostring(e), 2)
    end)
    if not ok then
        MAMLog.Error("%s falhou: %s", tostring(where), tostring(err))
        return false, err
    end
    return true, result
end

--- Envelopa um callback preservando TODOS os argumentos e o retorno.
function MAMLog.Guarded(where, fn)
    if type(fn) ~= "function" then
        return fn
    end
    return function(...)
        local args = { ... }
        local result = nil
        local ok, err = xpcall(function()
            result = { fn(unpack_fn(args)) }
        end, function(e)
            return debug.traceback(tostring(e), 2)
        end)
        if not ok then
            MAMLog.Error("%s: %s", tostring(where), tostring(err))
            return
        end
        return unpack_fn(result)
    end
end

return MAMLog
