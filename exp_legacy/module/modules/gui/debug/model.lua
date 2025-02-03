local Gui = require("modules.exp_legacy.utils.gui") --- @dep utils.gui
local ExpUtil = require("modules/exp_util")

local concat = table.concat
local inspect = table.inspect
local pcall = pcall
local loadstring = loadstring --- @diagnostic disable-line
local rawset = rawset

local Public = {}

local inspect_process = ExpUtil.safe_value

local inspect_options = { process = inspect_process }
function Public.dump(data)
    return inspect(data, inspect_options)
end

local dump = Public.dump

function Public.dump_ignore_builder(ignore)
    local function process(item)
        if ignore[item] then
            return nil
        end

        return inspect_process(item)
    end

    local options = { process = process }
    return function(data)
        return inspect(data, options)
    end
end

function Public.dump_function(func)
    local res = { "upvalues:\n", "no longer available" }

    local i = 1
    --[[while true do
        local n, v = debug.getupvalue(func, i)

        if n == nil then
            break
        elseif n ~= "_ENV" then
            res[#res + 1] = n
            res[#res + 1] = " = "
            res[#res + 1] = dump(v)
            res[#res + 1] = "\n"
        end

        i = i + 1
    end]]

    return concat(res)
end

function Public.dump_text(text, player)
    local func = loadstring("return " .. text)
    if not func then
        return false
    end

    rawset(game, "player", player)

    local suc, var = pcall(func)

    rawset(game, "player", nil)

    if not suc then
        return false
    end

    return true, dump(var)
end

return Public
