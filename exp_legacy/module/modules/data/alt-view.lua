--- Stores if you use alt mode or not and auto applies it
-- @data Alt-View

local Event = require("modules/exp_legacy/utils/event") --- @dep utils.event

--- Stores the visible state of alt mode
local PlayerData = require("modules.exp_legacy.expcore.player_data") --- @dep expcore.player_data
local UsesAlt = PlayerData.Settings:combine("UsesAlt")
UsesAlt:set_default(false)
UsesAlt:set_metadata{
    stringify = function(value) return value and "Visible" or "Hidden" end,
}

--- When your data loads apply alt view if you have it enabled
UsesAlt:on_load(function(player_name, uses_alt)
    local player = game.players[player_name]
    if uses_alt ~= nil then
        player.game_view_settings.show_entity_info = uses_alt
    end
end)

--- When alt view is toggled update this
Event.add(defines.events.on_player_toggled_alt_mode, function(event)
    local player = game.players[event.player_index]
    UsesAlt:set(player, player.game_view_settings.show_entity_info)
end)
