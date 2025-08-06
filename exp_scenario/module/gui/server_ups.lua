--[[-- Gui - Server UPS
Adds a server ups counter in the top right corner and a command to toggle it
]]

local Gui = require("modules/exp_gui")
local Commands = require("modules/exp_commands")
local External = require("modules/exp_legacy/expcore/external")

--- Stores the visible state of server ups
local PlayerData = require("modules/exp_legacy/expcore/player_data")
local UsesServerUps = PlayerData.Settings:combine("UsesServerUps")
UsesServerUps:set_default(false)
UsesServerUps:set_metadata{
    permission = "command/server-ups",
    stringify = function(value) return value and "Visible" or "Hidden" end,
}

--- Label to show the server ups
local server_ups = Gui.element("server_ups")
    :track_all_elements()
    :draw{
        type = "label",
        caption = "SUPS: N/A",
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

--- Change the visible state when your data loads
UsesServerUps:on_load(function(player_name, visible)
    if visible == nil or not External.valid() or not storage.ext.var.server_ups then
        visible = false
    end
    local player = assert(game.get_player(player_name))
    server_ups.data[player].visible = visible or false
end)

--- Toggles if the server ups is visbile
Commands.new("server-ups", { "server-ups.description" })
    :add_aliases{ "sups", "ups" }
    :register(function(player)
        local element = server_ups.data[player]
        if not External.valid() then
            element.visible = false
            return Commands.status.error{ "server-ups.no-ext" }
        end

        local visible = not UsesServerUps:get(player)
        UsesServerUps:set(player, visible)
        element.visible = visible
    end)

--- Set the location of the label
local function set_location(event)
    local player = game.players[event.player_index]
    local element = server_ups.data[player]
    if not element then
        element = server_ups(player.gui.screen)
        element.visible = UsesServerUps:get(player)
    end

    local res = player.display_resolution
    local uis = player.display_scale
    element.location = { x = res.width - 363 * uis, y = 31 * uis } -- below ups and clock
end

--- Update the caption for all online players
local function update_caption()
    if not External.valid() then
        return
    end

    local sups = External.get_server_ups()
    local caption = ("%s (%.1f%%)"):format(sups, sups * 5 / 3)
    for _, element in server_ups:online_elements() do
        element.caption = caption
    end
end

local e = defines.events

return {
    events = {
        [e.on_player_created] = set_location,
        [e.on_player_joined_game] = set_location,
        [e.on_player_display_resolution_changed] = set_location,
        [e.on_player_display_scale_changed] = set_location,
    },
    on_nth_tick = {
        [60] = update_caption,
    }
}
