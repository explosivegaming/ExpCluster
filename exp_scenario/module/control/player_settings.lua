--[[-- Control - Player Settings
Sends settings of players to the controller, which keeps them between servers
]]

local clusterio_api = require("modules/clusterio/api")

--- @param event EventData.on_player_joined_game | EventData.on_player_locale_changed
local function send_locale(event)
    local player = assert(game.get_player(event.player_index))
    clusterio_api.send_json("exp_scenario:locale", { player_name = player.name, locale = player.locale })
end

local e = defines.events

return {
    events = {
        [e.on_player_joined_game] = send_locale,
        [e.on_player_locale_changed] = send_locale,
    },
}
