--- Stores the language used to join the server
-- @data Language

local Event = require("modules/exp_legacy/utils/event") --- @dep utils.event
local PlayerData = require("modules.exp_legacy.expcore.player_data") --- @dep expcore.player_data
local LocalLanguage = PlayerData.Statistics:combine("LocalLanguage")
LocalLanguage:set_default("Unknown")

local function set_locale(event)
    local player = game.players[event.player_index]
    LocalLanguage:set(player, player.locale)
end

--- Set the players language when they join and change language
Event.add(defines.events.on_player_created, set_locale)
Event.add(defines.events.on_player_joined_game, set_locale)
Event.add(defines.events.on_player_locale_changed, set_locale)
