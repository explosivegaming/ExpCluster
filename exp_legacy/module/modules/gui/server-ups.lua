--[[-- Gui Module - Server UPS
    - Adds a server ups counter in the top right and a command to toggle is
    @gui server-ups
    @alias server_ups
]]

local Gui = require("modules.exp_legacy.expcore.gui") --- @dep expcore.gui
local Event = require("modules/exp_legacy/utils/event") --- @dep utils.event
local External = require("modules.exp_legacy.expcore.external") --- @dep expcore.external
local Commands = require("modules/exp_commands")

--- Stores the visible state of server ups
local PlayerData = require("modules.exp_legacy.expcore.player_data") --- @dep expcore.player_data
local UsesServerUps = PlayerData.Settings:combine("UsesServerUps")
UsesServerUps:set_default(false)
UsesServerUps:set_metadata{
    permission = "command/server-ups",
    stringify = function(value) return value and "Visible" or "Hidden" end,
}

--- Label to show the server ups
-- @element server_ups
local server_ups =
    Gui.element{
        type = "label",
        caption = "SUPS = 60.0",
        name = Gui.unique_static_name,
    }
    :style{
        font = "default-game",
    }

--- Change the visible state when your data loads
UsesServerUps:on_load(function(player_name, visible)
    local player = game.players[player_name]
    local label = player.gui.screen[server_ups.name]
    --- @diagnostic disable-next-line undefined-field
    if not External.valid() or not storage.ext.var.server_ups then visible = false end
    label.visible = visible
end)

--- Toggles if the server ups is visbile
Commands.new("server-ups", { "server-ups.description" })
    :add_aliases{ "sups", "ups" }
    :register(function(player)
        local label = player.gui.screen[server_ups.name]
        if not External.valid() then
            label.visible = false
            return Commands.status.error{ "server-ups.no-ext" }
        end
        label.visible = not label.visible
        UsesServerUps:set(player, label.visible)
    end)

-- Set the location of the label
-- 1920x1080: x=1455, y=30 (ui scale 100%)
local function set_location(event)
    local player = game.players[event.player_index]
    local label = player.gui.screen[server_ups.name]
    if not label then
        label = server_ups(player.gui.screen)
        label.visible = UsesServerUps:get(player)
    end
    local res = player.display_resolution
    local uis = player.display_scale
    -- below ups and clock
    -- label.location = {x=res.width-423*uis, y=50*uis}
    label.location = { x = res.width - 363 * uis, y = 31 * uis }
end

-- Draw the label when the player joins
Event.add(defines.events.on_player_created, set_location)

-- Update the caption for all online players
-- percentage of game speed
Event.on_nth_tick(60, function()
    if External.valid() then
        local caption = External.get_server_ups() .. " (" .. string.format("%.1f", External.get_server_ups() * 5 / 3) .. "%)"
        for _, player in pairs(game.connected_players) do
            player.gui.screen[server_ups.name].caption = caption
        end
    end
end)

-- Update when res or ui scale changes
Event.add(defines.events.on_player_display_resolution_changed, set_location)
Event.add(defines.events.on_player_display_scale_changed, set_location)
