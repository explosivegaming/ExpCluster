--[[ Gui - Elements
A collection of standalone elements that are reused between GUIs
]]

local Gui = require("modules/exp_gui")

--- @class ExpGui_Elements
local Elements = {}

--- Dropdown which allows selecting an online player
--- @class ExpGui_Elements.online_player_dropdown: ExpElement
Elements.online_player_dropdown = Gui.element("player_dropdown")
    :track_all_elements()
    :draw(function(def, parent)
        local names = Elements.online_player_dropdown.player_names
        return parent.add{
            type = "drop-down",
            items = names,
            selected_index = #names > 0 and 1 or nil,
        }
    end)
    :style{
        --horizontally_stretchable = true,
        height = 24,
    }

--- To help with caching and avoid context changes the player list from the previous update is remembered
--- @type string[]
Elements.online_player_dropdown.player_names = {}

--- Update all player dropdowns to match the currently online players
--- We don't split join and leave because the order would be inconsistent between players and cause desyncs
local function update_player_dropdown()
    local names = Elements.online_player_dropdown.player_names
    names[#names] = nil -- Nil last element to account for player leave

    for i, player in pairs(game.connected_players) do
        names[i] = player.name
    end

    for _, element in Elements.online_player_dropdown:online_elements() do
        element.items = names
    end
end

local e = defines.events

--- @package
Elements.events = {
    [e.on_player_joined_game] = update_player_dropdown,
    [e.on_player_left_game] = update_player_dropdown,
}

return Elements
