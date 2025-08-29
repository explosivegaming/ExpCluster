--[[-- Gui - Elements
A collection of standalone elements that are reused between GUIs
]]

local Gui = require("modules/exp_gui")

--- @class ExpGui_Elements
local Elements = {}

--- To help with caching and avoid context changes the player list from the previous update is remembered
--- @type (string?)[]
local _player_names = {}

--- Dropdown which allows selecting an online player
--- @class ExpGui_Elements.online_player_dropdown: ExpElement
--- @overload fun(parent: LuaGuiElement): LuaGuiElement
Elements.online_player_dropdown = Gui.define("player_dropdown")
    :track_all_elements()
    :draw(function(def, parent)
        return parent.add{
            type = "drop-down",
            items = _player_names,
            selected_index = #_player_names > 0 and 1 or nil,
        }
    end)
    :style{
        height = 24,
    } --[[ @as any ]]

--- Get the selected player name from a online player dropdown
--- @param online_player_dropdown LuaGuiElement
--- @return string
function Elements.online_player_dropdown.get_selected_name(online_player_dropdown)
    local name = _player_names[online_player_dropdown.selected_index]
    if not name then
        online_player_dropdown.selected_index = 1
        name = _player_names[1] --- @cast name -nil
    end
    return name
end

--- Get the selected player from a online player dropdown
--- @param online_player_dropdown LuaGuiElement
--- @return LuaPlayer
function Elements.online_player_dropdown.get_selected(online_player_dropdown)
    local name = _player_names[online_player_dropdown.selected_index]
    if not name then
        online_player_dropdown.selected_index = 1
        name = _player_names[1] --- @cast name -nil
    end
    return assert(game.get_player(name))
end


--- Get the number of players in the dropdown
--- @return number
function Elements.online_player_dropdown.get_player_count()
    return #_player_names
end

--- Update all player dropdowns to match the currently online players
--- We don't split join and leave because the order would be inconsistent between players and cause desyncs
function Elements.online_player_dropdown.refresh_online()
    _player_names[#_player_names] = nil -- Nil last element to account for player leave

    for i, player in pairs(game.connected_players) do
        _player_names[i] = player.name
    end

    for _, online_player_dropdown in Elements.online_player_dropdown:online_elements() do
        online_player_dropdown.items = _player_names
    end
end

local e = defines.events

--- @package
Elements.events = {
    [e.on_player_joined_game] = Elements.online_player_dropdown.refresh_online,
    [e.on_player_left_game] = Elements.online_player_dropdown.refresh_online,
}

return Elements
