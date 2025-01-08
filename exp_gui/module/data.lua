--[[-- ExpGui - GuiData
Provides a method of storing data for elements, players, and forces under a given scope.
This is not limited to GUI element definitions but this is the most common use case.
]]

local ExpUtil = require("modules/exp_util")
local Storage = require("modules/exp_util/storage")

--- @type table<string, ExpGui.GuiData>
local registered_scopes = {}

--- @type table<uint, uint> Reg -> Player Index
local registration_numbers = {}
local reg_obj = script.register_on_object_destroyed

--- @type table<string, [table<uint, table<uint, any>>, table<uint, any>, table<uint, any>, table]>
local scope_data = {}

Storage.register({
    scope_data = scope_data, 
    registration_numbers = registration_numbers,
}, function(tbl)
    registration_numbers = tbl.registration_numbers
    for scope, data in pairs(tbl.scope_data) do
        local proxy = registered_scopes[scope]
        if proxy then
            proxy.element_data = data[1]
            proxy.player_data = data[2]
            proxy.force_data = data[3]
            proxy.global_data = data[4]
        end
    end
end)

--- @class ExpGui_GuiData
local GuiData = {
    _scopes = registered_scopes,
}

--- @alias DataKey LuaGuiElement | LuaPlayer | LuaForce

--- @class ExpGui.GuiData: table<DataKey, any>
--- @field _scope string
--- @field _owner any
--- @field element_data table<uint, table<uint, any>>
--- @field player_data table<uint, any>
--- @field force_data table<uint, any>
--- @field global_data table
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
    local object_name = key.object_name
    if object_name == "LuaGuiElement" then
        local player_elements = self.element_data[key.player_index]
        return player_elements and player_elements[key.index]
    elseif object_name == "LuaPlayer" then
        return self.player_data[key.index]
    elseif object_name == "LuaForce" then
        return self.force_data[key.index]
    else
        error("Unsupported object class '" .. object_name .. "' given as index to GuiData.")
    end
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
        registration_numbers[reg_obj(key)] = key.player_index
    elseif object_name == "LuaPlayer" then
        self.player_data[key.index] = value
    elseif object_name == "LuaForce" then
        self.force_data[key.index] = value
    else
        error("Unsupported object class '" .. object_name .. "' given as index to GuiData.")
    end
end

--- Create the data object for a given scope
--- @param scope string
--- @return ExpGui.GuiData
function GuiData.create(scope)
    assert(GuiData._scopes[scope] == nil, "Scope already exists with name: " .. scope)

    local instance = {
        _scope = scope,
        element_data = {},
        player_data = {},
        force_data = {},
        global_data = {},
    }

    scope_data[scope] = {
        instance.element_data,
        instance.player_data,
        instance.force_data,
        instance.global_data,
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

--- Used to clean up data from destroyed elements
--- @param event EventData.on_object_destroyed
local function on_object_destroyed(event)
    local player_index = registration_numbers[event.registration_number]
    if not player_index then return end

    local element_index = event.useful_id
    registration_numbers[event.registration_number] = nil

    for _, scope in pairs(registered_scopes) do
        local player_elements = scope.element_data[player_index]
        if player_elements then
            player_elements[element_index] = nil
        end
    end
end

--- Used to clean up data from destroyed players
--- @param event EventData.on_player_removed
local function on_player_removed(event)
    local player_index = event.player_index
    for _, scope in pairs(registered_scopes) do
        scope.player_data[player_index] = nil
    end
end

--- Used to clean up data from destroyed forces
--- @param event EventData.on_forces_merged
local function on_forces_merged(event)
    local force_index = event.source_index
    for _, scope in pairs(registered_scopes) do
        scope.force_data[force_index] = nil
    end
end

local e = defines.events
local events = {
    [e.on_object_destroyed] = on_object_destroyed,
    [e.on_player_removed] = on_player_removed,
    [e.on_forces_merged] = on_forces_merged,
}

GuiData.events = events
return GuiData
