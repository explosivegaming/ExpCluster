--- Stores the language used to join the server
-- @data Language

local Event = require("modules/exp_legacy/utils/event") ---@dep utils.event
local PlayerData = require("modules.exp_legacy.expcore.player_data") --- @dep expcore.player_data
local LocalLanguage = PlayerData.Statistics:combine('LocalLanguage')
LocalLanguage:set_default("Unknown")

--- Creates translation request on_load of a player
LocalLanguage:on_load(function(player_name, _)
  local player = game.players[player_name]
  player.request_translation({"language.local-language"})
end)

--- Resolves translation request for language setting
Event.add(defines.events.on_string_translated, function(event)
  -- Check if event.localised_string is a table
  -- Check if the translation request was for language setting
  if type(event.localised_string) ~= "table" or event.localised_string[1] ~= "language.local-language" then
    return
  end

  -- Check if the translation request was succesful
  local player = game.players[event.player_index]
  if not event.translated then
    player.print("Could not detect your language settings")
    -- Raise error
    return
  end

  -- Change LocalLanguage value for the player to the recognized one
  local language = event.result
  LocalLanguage:set(player, language)
end)