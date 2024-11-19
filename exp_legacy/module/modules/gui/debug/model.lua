local Gui = require("modules.exp_legacy.utils.gui") --- @dep utils.gui

local gui_names = Gui.names
local type = type
local concat = table.concat
local inspect = table.inspect
local pcall = pcall
local loadstring = loadstring --- @diagnostic disable-line
local rawset = rawset

local Public = {}

local LuaObject = { "{", nil, ", name = '", nil, "'}" }
local LuaPlayer = { "{LuaPlayer, name = '", nil, "', index = ", nil, "}" }
local LuaEntity = { "{LuaEntity, name = '", nil, "', unit_number = ", nil, "}" }
local LuaGuiElement = { "{LuaGuiElement, name = '", nil, "'}" }

local function get(obj, prop)
    return obj[prop]
end

local function get_name_safe(obj)
    local s, r = pcall(get, obj, "name")
    if not s then
        return "nil"
    else
        return r or "nil"
    end
end

local function get_lua_object_type_safe(obj)
    local s, r = pcall(get, obj, "help")

    if not s then
        return
    end

    return r():match("Lua%a+")
end

local function inspect_process(item)
    if type(item) ~= "table" or type(item.__self) ~= "userdata" then
        return item
    end

    local suc, valid = pcall(get, item, "valid")
    if not suc then
        -- no 'valid' property
        return get_lua_object_type_safe(item) or "{NoHelp LuaObject}"
    end

    if not valid then
        return "{Invalid LuaObject}"
    end

    local obj_type = get_lua_object_type_safe(item)
    if not obj_type then
        return "{NoHelp LuaObject}"
    end

    if obj_type == "LuaPlayer" then
        LuaPlayer[2] = item.name or "nil"
        LuaPlayer[4] = item.index or "nil"

        return concat(LuaPlayer)
    elseif obj_type == "LuaEntity" then
        LuaEntity[2] = item.name or "nil"
        LuaEntity[4] = item.unit_number or "nil"

        return concat(LuaEntity)
    elseif obj_type == "LuaGuiElement" then
        local name = item.name
        LuaGuiElement[2] = gui_names and gui_names[name] or name or "nil"

        return concat(LuaGuiElement)
    else
        LuaObject[2] = obj_type
        LuaObject[4] = get_name_safe(item)

        return concat(LuaObject)
    end
end

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
