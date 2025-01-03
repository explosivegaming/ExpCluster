--[[-- ExpGui - GuiData
Provides a method of storing elements created for a player and provide a global iterator for them.
]]

local ExpUtil = require("modules/exp_util")
local Storage = require("modules/exp_util/storage")

--- @alias ExpGui_GuiIter.FilterType LuaPlayer | LuaForce | LuaPlayer[] | nil
--- @alias ExpGui_GuiIter.ReturnType ExpGui_GuiIter.ReturnType

--- @type table<string, table<uint, table<uint, LuaGuiElement>>>
local script_data = {}
Storage.register(script_data, function(tbl)
    script_data = tbl
end)

--- @class ExpGui_GuiIter
local GuiIter = {
    _elements = script_data,
}

local function nop() return nil, nil end

--- Get the next valid element
--- @param elements table<uint, LuaGuiElement>
--- @param prev_index uint?
--- @return uint?, LuaGuiElement?
local function next_valid_element(elements, prev_index)
    local element_index, element = next(elements, prev_index)
    while element and not element.valid do
        elements[element_index] = nil
        element_index, element = next(elements, element_index)
    end
    return element_index, element
end

--- Get the next valid player with elements
--- @param scope_elements table<uint, table<uint, LuaGuiElement>>
--- @param players LuaPlayer[]
--- @param prev_index uint?
--- @param online boolean?
--- @return uint?, LuaPlayer?, table<uint, LuaGuiElement>?
local function next_valid_player(scope_elements, players, prev_index, online)
    local index, player = nil, nil
    while true do
        index, player = next(players, prev_index)
        while player and not player.valid do
            scope_elements[player.index] = nil
            index, player = next(players, index)
        end

        if index == nil then
            return nil, nil, nil
        end

        if online == nil or player.connected == online then
            local player_elements = scope_elements[player.index]
            if player_elements and #player_elements > 0 then
                return index, player, player_elements
            end
        end
    end
end

--- Iterate over all valid elements for a player
--- @param scope string
--- @param player LuaPlayer
--- @return ExpGui_GuiIter.ReturnType
function GuiIter.player_elements(scope, player)
    if not player.valid then return nop end

    local scope_elements = script_data[scope]
    if not scope_elements then return nop end

    local player_elements = scope_elements[player.index]
    if not player_elements then return nop end

    local element_index, element = nil, nil
    return function()
        element_index, element = next_valid_element(player_elements, element_index)
        if element_index == nil then return nil, nil end
        return player, element
    end
end

--- Iterate over all valid elements for a player
--- @param scope string
--- @param players LuaPlayer[]
--- @param online boolean?
--- @return ExpGui_GuiIter.ReturnType
function GuiIter.filtered_elements(scope, players, online)
    local scope_elements = script_data[scope]
    if not scope_elements then return nop end

    local index, player, player_elements = nil, nil, nil
    local element_index, element = nil, nil
    return function()
        while true do
            -- Get the next valid player elements if needed
            if element_index == nil then
                index, player, player_elements = next_valid_player(scope_elements, players, index, online)
                if index == nil then return nil, nil end
                --- @cast player_elements -nil
            end

            -- Get the next element
            element_index, element = next_valid_element(player_elements, element_index)
            if element_index then
                return player, element
            end
        end
    end
end

--- Iterate over all valid elements
--- @param scope string
--- @return ExpGui_GuiIter.ReturnType
function GuiIter.all_elements(scope)
    local scope_elements = script_data[scope]
    if not scope_elements then return nop end

    local player_index, player_elements, player = nil, nil, nil
    local element_index, element = nil, nil
    return function()
        while true do
            if element_index == nil then
                -- Get the next player
                player_index, player_elements = next(scope_elements, player_index)
                if player_index == nil then return nil, nil end
                player = game.get_player(player_index)

                -- Ensure next player is valid
                while player and not player.valid do
                    scope_elements[player_index] = nil
                    player_index, player_elements = next(scope_elements, player_index)
                    if player_index == nil then return nil, nil end
                    player = game.get_player(player_index)
                end
                --- @cast player_elements -nil
            end

            -- Get the next element
            element_index, element = next_valid_element(player_elements, element_index)
            if element_index then
                return player, element
            end
        end
    end
end

--- Iterate over all valid gui elements for all players
--- @param scope string
--- @param filter ExpGui_GuiIter.FilterType
--- @return ExpGui_GuiIter.ReturnType
function GuiIter.get_tracked_elements(scope, filter)
    local class_name = ExpUtil.get_class_name(filter)
    if class_name == "nil" then
        --- @cast filter nil
        return GuiIter.all_elements(scope)
    elseif class_name == "LuaPlayer" then
        --- @cast filter LuaPlayer
        return GuiIter.player_elements(scope, filter)
    elseif class_name == "LuaForce" then
        --- @cast filter LuaForce
        return GuiIter.filtered_elements(scope, filter.players)
    elseif type(filter) == "table" and ExpUtil.get_class_name(filter[1]) == "LuaPlayer" then
        --- @cast filter LuaPlayer[]
        return GuiIter.filtered_elements(scope, filter)
    else
        error("Unknown filter type: " .. class_name)
    end
end

--- Iterate over all valid gui elements for all online players
--- @param scope string
--- @param filter ExpGui_GuiIter.FilterType
--- @return ExpGui_GuiIter.ReturnType
function GuiIter.get_online_elements(scope, filter)
    local class_name = ExpUtil.get_class_name(filter)
    if class_name == "nil" then
        --- @cast filter nil
        return GuiIter.filtered_elements(scope, game.connected_players)
    elseif class_name == "LuaPlayer" then
        --- @cast filter LuaPlayer
        if not filter.connected then return nop end
        return GuiIter.player_elements(scope, filter)
    elseif class_name == "LuaForce" then
        --- @cast filter LuaForce
        return GuiIter.filtered_elements(scope, filter.connected_players)
    elseif type(filter) == "table" and ExpUtil.get_class_name(filter[1]) == "LuaPlayer" then
        --- @cast filter LuaPlayer[]
        return GuiIter.filtered_elements(scope, filter, true)
    else
        error("Unknown filter type: " .. class_name)
    end
end

--- Add a new element to the global iter
--- @param scope string
--- @param element LuaGuiElement
function GuiIter.add_element(scope, element)
    if not element.valid then return end

    local scope_elements = script_data[scope]
    if not scope_elements then
        scope_elements = {}
        script_data[scope] = scope_elements
    end

    local player_elements = script_data[element.player_index]
    if not player_elements then
        player_elements = {}
        script_data[element.player_index] = player_elements
    end

    player_elements[element.index] = element
end

--- Remove an element from the global iter
--- @param scope string
--- @param player_index uint
--- @param element_index uint
function GuiIter.remove_element(scope, player_index, element_index)
    local scope_elements = script_data[scope]
    if not scope_elements then return end
    local player_elements = script_data[player_index]
    if not player_elements then return end
    player_elements[element_index] = nil
end

return GuiIter
