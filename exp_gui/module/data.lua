
local ExpUtil = require("modules/exp_util")
local Storage = require("modules/exp_util/storage")

--- @type table<string, ExpGui.GuiData>
local script_data = {}
Storage.register(script_data, function(tbl)
    script_data = tbl
end)

--- @class ExpGui_GuiData
local GuiData = {
    _gui_data = script_data,
    _registered = {}, --- @type table<string, ExpGui.GuiDataInit>
}

--- @alias DataKey LuaGuiElement | LuaPlayer | LuaForce

--- @class ExpGui.GuiData: table<DataKey, any>
--- @field _init ExpGui.GuiDataInit
--- @field element_data table<uint, table<uint, any>>
--- @field player_data table<uint, any>
--- @field force_data table<uint, any>

--- @class ExpGui.GuiDataInit
--- @field element any
--- @field player any
--- @field force any

--- Return the index for a given key
--- @param self ExpGui.GuiData
--- @param key DataKey
--- @return any
function GuiData.__index(self, key)
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
function GuiData.__newindex(self, key, value)
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

GuiData._metatable = {
    __index = GuiData.__index,
    __newindex = GuiData.__newindex,
    __class = "GuiData",
}

Storage.register_metatable(GuiData._metatable.__class, GuiData._metatable)

--- Register the starting values for element data
--- @param define_name string
--- @param init_element any
--- @param init_player any
--- @param init_force any
function GuiData.register(define_name, init_element, init_player, init_force)
    assert(GuiData._registered[define_name] == nil, "Define already has data registered")
    GuiData._registered[define_name] = {
        element = init_element,
        player = init_player,
        force = init_force,
    }
end

--- Create the data for an element definition
--- @param define_name string
--- @return ExpGui.GuiData
function GuiData.create(define_name)
    local init = assert(GuiData._registered[define_name], "Define does not have any registered data")

    local data = {
        _init = init,
        element_data = {},
        player_data = {},
        force_data = {},
    }

    script_data[define_name] = data
    return setmetatable(data, GuiData._metatable)
end

return GuiData
