--[[-- Gui - GuiData
Provides a method of storing data for elements, players, and forces under a given scope.
This is not limited to GUI element definitions but this is the most common use case.
]]

local ExpUtil = require("modules/exp_util")
local Storage = require("modules/exp_util/storage")

--- @type table<string, GuiData_Raw>
local scope_data = {}

--- @type table<string, GuiData_Internal>
local registered_scopes = {}

--- @type table<uint, uint> Reg -> Player Index
local registration_numbers = {}
local reg_obj = script.register_on_object_destroyed

--- @alias DataKey LuaGuiElement | LuaPlayer | LuaForce
--- @alias DataKeys "element_data" | "player_data" | "force_data" | "global_data"
local DataKeys = ExpUtil.enum{ "element_data", "player_data", "force_data", "global_data" }
local DataKeysConcat = table.concat(DataKeys, ", ")

Storage.register({
    scope_data = scope_data,
    registration_numbers = registration_numbers,
}, function(tbl)
    scope_data = tbl.scope_data
    registration_numbers = tbl.registration_numbers
    for scope, data in pairs(tbl.scope_data) do
        local proxy = registered_scopes[scope]
        if proxy then
            rawset(proxy, "_raw", data)
            for k, v in pairs(data) do
                rawset(proxy, k, v)
            end
        end
    end
end)

--- @class _GuiData
local GuiData = {
    _scopes = registered_scopes,
}

--- @class GuiData_Raw
--- @field element_data table<uint, table<uint, any>?>?
--- @field player_data table<uint, any>?
--- @field force_data table<uint, any>?
--- @field global_data table?
-- This class has no prototype methods
-- Keep this in sync with DataKeys to block arbitrary strings

--- @class GuiData_Internal
--- @field _scope string
--- @field _raw GuiData_Raw
-- This class has no prototype methods
-- Do add keys to _raw without also referencing scope_data

--- @class GuiData: GuiData_Internal
--- @field element_data table<uint, table<uint, any>>
--- @field player_data table<uint, any>
--- @field force_data table<uint, any>
--- @field global_data table
-- This class has no prototype methods
-- Same as raw but __index ensures the values exist

GuiData._metatable = {
    __class = "GuiData",
}

--- Return the index for a given key
--- @param self GuiData_Internal
--- @param key DataKeys | DataKey
--- @return any
function GuiData._metatable.__index(self, key)
    if type(key) == "string" then
        -- This is only called when the key does not exist, ie it is not in storage
        -- Once created, these tables are never removed as they are likely to be used again
        assert(DataKeys[key], "Valid keys are: " .. DataKeysConcat)
        local value = {}
        self._raw[key] = value
        rawset(self, key, value)
        scope_data[self._scope] = self._raw
        return value
    end

    -- Check a given child table based on the object type
    assert(type(key) == "userdata", "Index type '" .. ExpUtil.get_class_name(key) .. "' given to GuiData. Must be of type userdata.")
    local object_name = key.object_name --- @diagnostic disable-line assign-type-mismatch
    if object_name == "LuaGuiElement" then
        local data = self._raw.element_data
        local player_elements = data and data[key.player_index]
        return player_elements and player_elements[key.index]
    elseif object_name == "LuaPlayer" then
        local data = self._raw.player_data
        return data and data[key.index]
    elseif object_name == "LuaForce" then
        local data = self._raw.force_data
        return data and data[key.index]
    else
        error("Unsupported object class '" .. object_name .. "' given as index to GuiData.")
    end
end

--- Set the value index of a given key
-- Internal type is not used here to allow for creation of storage
--- @param self GuiData
--- @param key DataKey
--- @param value unknown
function GuiData._metatable.__newindex(self, key, value)
    assert(type(key) == "userdata", "Index type '" .. ExpUtil.get_class_name(key) .. "' given to GuiData. Must be of type userdata.")
    local object_name = key.object_name
    if object_name == "LuaGuiElement" then
        --- @cast key LuaGuiElement
        local data = self.element_data
        local player_elements = data[key.player_index]
        if not player_elements then
            player_elements = {}
            data[key.player_index] = player_elements
        end
        player_elements[key.index] = value
        registration_numbers[reg_obj(key)] = key.player_index
    elseif object_name == "LuaPlayer" then
        --- @cast key LuaPlayer
        self.player_data[key.index] = value
    elseif object_name == "LuaForce" then
        --- @cast key LuaForce
        self.force_data[key.index] = value
    else
        error("Unsupported object class '" .. object_name .. "' given as index to GuiData.")
    end
end

--- Create the data object for a given scope
--- @param scope string
--- @return GuiData
function GuiData.create(scope)
    ExpUtil.assert_not_runtime()
    assert(GuiData._scopes[scope] == nil, "Scope already exists with name: " .. scope)

    local instance = {
        _scope = scope,
        _raw = {},
    }

    GuiData._scopes[scope] = instance
    --- @cast instance GuiData
    return setmetatable(instance, GuiData._metatable)
end

--- Get the link to an existing data scope
--- @param scope string
--- @return GuiData
function GuiData.get(scope)
    return GuiData._scopes[scope] --[[ @as GuiData ]]
end

--- Used to clean up data from destroyed elements
--- @param event EventData.on_object_destroyed
local function on_object_destroyed(event)
    local player_index = registration_numbers[event.registration_number]
    if not player_index then return end

    local element_index = event.useful_id
    registration_numbers[event.registration_number] = nil

    for _, scope in pairs(registered_scopes) do
        local data = scope._raw.element_data
        local player_elements = data and data[player_index]
        if player_elements then
            player_elements[element_index] = nil
            if not next(player_elements) then
                data[player_index] = nil
            end
        end
    end
end

--- Used to clean up data from destroyed players
--- @param event EventData.on_player_removed
local function on_player_removed(event)
    local player_index = event.player_index
    for _, scope in pairs(registered_scopes) do
        local data = scope._raw.player_data
        if data then
            data[player_index] = nil
        end
    end
end

--- Used to clean up data from destroyed forces
--- @param event EventData.on_forces_merged
local function on_forces_merged(event)
    local force_index = event.source_index
    for _, scope in pairs(registered_scopes) do
        local data = scope._raw.force_data
        if data then
            data[force_index] = nil
        end
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
