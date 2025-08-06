--[[-- Gui - Server UPS
Adds a server ups counter in the top right corner and a command to toggle it
]]

local Gui = require("modules/exp_gui")
local ExpUtil = require("modules/exp_util")
local Commands = require("modules/exp_commands")

--- Label to show the server ups, drawn to screen on join
local server_ups = Gui.element("server_ups")
    :track_all_elements()
    :draw{
        type = "label",
        name = Gui.property_from_name,
    }
    :style{
        font = "default-game",
    }
    :player_data(function(def, element)
        local player = Gui.get_player(element)
        local existing = def.data[player]
        if not existing or not existing.valid then
            return element -- Only set if no previous
        end
    end)

--- Update the caption for all online players
--- @param ups number The UPS to be displayed
local function update_server_ups(ups)
    local caption = ("%.1f (%.1f%%)"):format(ups, ups * 5 / 3)
    for _, element in server_ups:online_elements() do
        element.caption = caption
    end
end

--- Stores the visible state of server ups element for a player
local PlayerData = require("modules/exp_legacy/expcore/player_data")
local UsesServerUps = PlayerData.Settings:combine("UsesServerUps")
UsesServerUps:set_default(false)
UsesServerUps:set_metadata{
    permission = "command/server-ups",
    stringify = function(value) return value and "Visible" or "Hidden" end,
}

--- Change the visible state when your data loads
UsesServerUps:on_load(function(player_name, visible)
    local player = assert(game.get_player(player_name))
    server_ups.data[player].visible = visible or false
end)

--- Toggles if the server ups is visbile
Commands.new("server-ups", { "exp_server-ups.description" })
    :add_aliases{ "sups", "ups" }
    :register(function(player)
        local visible = not UsesServerUps:get(player)
        server_ups.data[player].visible = visible
        UsesServerUps:set(player, visible)
    end)

--- Add an interface which can be called from rcon
Commands.add_rcon_static("exp_server_ups", {
    update = function(ups)
        ExpUtil.assert_argument_type(ups, "number", 1, "ups")
        update_server_ups(ups)
        return game.tick
    end
})

--- Set the location of the label
local function set_location(event)
    local player = game.players[event.player_index]
    local element = server_ups.data[player]
    if not element then
        element = server_ups(player.gui.screen)
        element.visible = UsesServerUps:get(player)
    end

    local uis = player.display_scale
    local res = player.display_resolution
    element.location = { x = res.width - 363 * uis, y = 31 * uis } -- below ups and clock
end

local e = defines.events

return {
    elements = {
        server_ups = server_ups,
    },
    events = {
        [e.on_player_created] = set_location,
        [e.on_player_joined_game] = set_location,
        [e.on_player_display_resolution_changed] = set_location,
        [e.on_player_display_scale_changed] = set_location,
    },
}
