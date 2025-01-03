--[[-- ExpGui - GuiData
Provides a method of storing data for elements, players, and forces under a given scope.
This is not limited to GUI element definitions but this is the most common use case.
]]

local ExpUtil = require("modules/exp_util")
local Storage = require("modules/exp_util/storage")

--- @type table<string, ExpGui.GuiData>
local registered_scopes = {}

--- @type table<string, [table, table, table]>
local script_data = {}
Storage.register(script_data, function(tbl)
    script_data = tbl
    for scope, data in pairs(tbl) do
        local proxy = registered_scopes[scope]
        if proxy then
            proxy.element_data = data[1]
            proxy.player_data = data[2]
            proxy.force_data = data[3]
        end
    end
end)

--- @class ExpGui_GuiData
local GuiData = {
    _data = script_data,
    _scopes = registered_scopes,
}

--- @alias DataKey LuaGuiElement | LuaPlayer | LuaForce

--- @class ExpGui.GuiData._init
--- @field element any
--- @field player any
--- @field force any

--- @class ExpGui.GuiData: table<DataKey, any>
--- @field _scope string
--- @field _init ExpGui.GuiData._init
--- @field element_data table<uint, table<uint, any>>
--- @field player_data table<uint, any>
--- @field force_data table<uint, any>
-- This class has no prototype methods

GuiData._metatable = {
    __class = "GuiData",
}

Storage.register_metatable(GuiData._metatable.__class, GuiData._metatable)

--- Return the index for a given key
--- @param self ExpGui.GuiData
--- @param key DataKey
--- @return any
function GuiData._metatable.__index(self, key)
    assert(type(key) == "userdata", "Index type '" .. ExpUtil.get_class_name(key) .. "' given to GuiData. Must be of type userdata.")
    local rtn, init
    local object_name = key.object_name
    if object_name == "LuaGuiElement" then
        local player_elements = self.element_data[key.player_index]
        rtn = player_elements and player_elements[key.index]
        init = self._init.element
    elseif object_name == "LuaPlayer" then
        rtn = self.player_data[key.index]
        init = self._init.player
    elseif object_name == "LuaForce" then
        rtn = self.force_data[key.index]
        init = self._init.force
    else
        error("Unsupported object class '" .. object_name .. "' given as index to GuiData.")
    end

    if rtn == nil then
        rtn = table.deep_copy(init)
        self[key] = rtn
    end

    return rtn
end

--- Set the value index of a given key
--- @param self ExpGui.GuiData
--- @param key DataKey
--- @param value unknown
function GuiData._metatable.__newindex(self, key, value)
    assert(type(key) == "userdata", "Index type '" .. ExpUtil.get_class_name(key) .. "' given to GuiData. Must be of type userdata.")
    local object_name = key.object_name
    if object_name == "LuaGuiElement" then
        local player_elements = self.element_data[key.player_index]
        if not player_elements then
            player_elements = {}
            self.element_data[key.player_index] = player_elements
        end
        player_elements[key.index] = value
    elseif object_name == "LuaPlayer" then
        self.player_data[key.index] = value
    elseif object_name == "LuaForce" then
        self.force_data[key.index] = value
    else
        error("Unsupported object class '" .. object_name .. "' given as index to GuiData.")
    end
end

--- Sallow copy the keys from the provided table into itself
--- @param self ExpGui.GuiData
--- @param data table
function GuiData._metatable.__call(self, data)
    for k, v in pairs(data) do
        self[k] = v
    end
end

--- Create the data object for a given scope
--- @param scope string
--- @return ExpGui.GuiData
function GuiData.create(scope)
    assert(GuiData._scopes[scope] == nil, "Scope already exists with name: " .. scope)

    local instance = {
        _init = {},
        _scope = scope,
        element_data = {},
        player_data = {},
        force_data = {},
    }

    script_data[scope] = {
        instance.element_data,
        instance.player_data,
        instance.force_data,
    }

    GuiData._scopes[scope] = instance
    return setmetatable(instance, GuiData._metatable)
end

--- Get the link to an existing data scope
--- @param scope string
--- @return ExpGui.GuiData
function GuiData.get(scope)
    return GuiData._scopes[scope]
end

return GuiData
