--- Gives players random colours when they are created, also applies preset colours to those who have them
--- Inventory sync restores the colour of players who have played before
-- @data Player-Colours

local Event = require("modules/exp_legacy/utils/event") --- @dep utils.event
local Colours = require("modules/exp_util/include/color")
local config = require("modules.exp_legacy.config.preset_player_colours") --- @dep config.preset_player_colours

--- Returns a colour that is a bit lighter than the one given
local function lighten(c)
    return { r = 255 - (255 - c.r) * 0.5, g = 255 - (255 - c.g) * 0.5, b = 255 - (255 - c.b) * 0.5, a = 255 }
end

--- Apply the preset colour of the player, or a random one if there is none
Event.add(defines.events.on_player_created, function(event)
    local player = game.players[event.player_index]
    local colour = config.players[player.name]
    if not colour then
        local colour_name = "white"
        while config.disallow[colour_name] do
            colour_name = table.get_random(Colours, true)
        end
        colour = Colours[colour_name]
    end

    player.color = colour
    player.chat_color = lighten(colour)
end)
