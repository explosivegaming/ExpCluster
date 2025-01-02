
local ExpUtil = require("modules/exp_util")
local Storage = require("modules/exp_util/storage")

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
--- @param define_elements table<uint, table<uint, LuaGuiElement>>
--- @param players LuaPlayer[]
--- @param prev_index uint?
--- @param online boolean?
--- @return uint?, LuaPlayer?, table<uint, LuaGuiElement>?
local function next_valid_player(define_elements, players, prev_index, online)
    local index, player = nil, nil
    while true do
        index, player = next(players, prev_index)
        while player and not player.valid do
            define_elements[player.index] = nil
            index, player = next(players, index)
        end

        if index == nil then
            return nil, nil, nil
        end

        if online == nil or player.connected == online then
            local player_elements = define_elements[player.index]
            if player_elements and #player_elements > 0 then
                return index, player, player_elements
            end
        end
    end
end

--- Iterate over all valid elements for a player
--- @param define_name string
--- @param player LuaPlayer
--- @return fun(): LuaPlayer?, LuaGuiElement?
function GuiIter.player_elements(define_name, player)
    if not player.valid then return nop end

    local define_elements = script_data[define_name]
    if not define_elements then return nop end

    local player_elements = define_elements[player.index]
    if not player_elements then return nop end

    local element_index, element = nil, nil
    return function()
        element_index, element = next_valid_element(player_elements, element_index)
        if element_index == nil then return nil, nil end
        return player, element
    end
end

--- Iterate over all valid elements for a player
--- @param define_name string
--- @param players LuaPlayer[]
--- @param online boolean?
--- @return fun(): LuaPlayer?, LuaGuiElement?
function GuiIter.filtered_elements(define_name, players, online)
    local define_elements = script_data[define_name]
    if not define_elements then return nop end

    local index, player, player_elements = nil, nil, nil
    local element_index, element = nil, nil
    return function()
        while true do
            -- Get the next valid player elements if needed
            if element_index == nil then
                index, player, player_elements = next_valid_player(define_elements, players, index, online)
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
--- @param define_name string
--- @return fun(): LuaPlayer?, LuaGuiElement?
function GuiIter.all_elements(define_name)
    local define_elements = script_data[define_name]
    if not define_elements then return nop end

    local player_index, player_elements, player = nil, nil, nil
    local element_index, element = nil, nil
    return function()
        while true do
            if element_index == nil then
                -- Get the next player
                player_index, player_elements = next(define_elements, player_index)
                if player_index == nil then return nil, nil end
                player = game.get_player(player_index)

                -- Ensure next player is valid
                while player and not player.valid do
                    define_elements[player_index] = nil
                    player_index, player_elements = next(define_elements, player_index)
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

--- @alias FilterType LuaPlayer | LuaForce | LuaPlayer[] | nil

--- Iterate over all valid gui elements for all players
--- @param define_name string
--- @param filter FilterType
--- @return fun(): LuaPlayer?, LuaGuiElement?
function GuiIter.get_elements(define_name, filter)
    local class_name = ExpUtil.get_class_name(filter)
    if class_name == "nil" then
        --- @cast filter nil
        return GuiIter.all_elements(define_name)
    elseif class_name == "LuaPlayer" then
        --- @cast filter LuaPlayer
        return GuiIter.player_elements(define_name, filter)
    elseif class_name == "LuaForce" then
        --- @cast filter LuaForce
        return GuiIter.filtered_elements(define_name, filter.players)
    elseif type(filter) == "table" and ExpUtil.get_class_name(filter[1]) == "LuaPlayer" then
        --- @cast filter LuaPlayer[]
        return GuiIter.filtered_elements(define_name, filter)
    else
        error("Unknown filter type: " .. class_name)
    end
end

--- Iterate over all valid gui elements for all online players
--- @param define_name string
--- @param filter FilterType
--- @return fun(): LuaPlayer?, LuaGuiElement?
function GuiIter.get_online_elements(define_name, filter)
    local class_name = ExpUtil.get_class_name(filter)
    if class_name == "nil" then
        --- @cast filter nil
        return GuiIter.filtered_elements(define_name, game.connected_players)
    elseif class_name == "LuaPlayer" then
        --- @cast filter LuaPlayer
        if not filter.connected then return nop end
        return GuiIter.player_elements(define_name, filter)
    elseif class_name == "LuaForce" then
        --- @cast filter LuaForce
        return GuiIter.filtered_elements(define_name, filter.connected_players)
    elseif type(filter) == "table" and ExpUtil.get_class_name(filter[1]) == "LuaPlayer" then
        --- @cast filter LuaPlayer[]
        return GuiIter.filtered_elements(define_name, filter, true)
    else
        error("Unknown filter type: " .. class_name)
    end
end

--- Add a new element to the global iter
--- @param define_name string
--- @param element LuaGuiElement
function GuiIter.add_element(define_name, element)
    if not element.valid then return end

    local define_elements = script_data[define_name]
    if not define_elements then
        define_elements = {}
        script_data[define_name] = define_elements
    end

    local player_elements = script_data[element.player_index]
    if not player_elements then
        player_elements = {}
        script_data[element.player_index] = player_elements
    end

    player_elements[element.index] = element
end

return GuiIter
