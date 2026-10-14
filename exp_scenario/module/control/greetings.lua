--[[-- Control - Greetings
Greets players when they join, and lets players set a message shown to everyone when they join

The join messages are kept by the controller, the instance plugin prints them when a player joins
]]

local Commands = require("modules/exp_commands")
local Feature = require("modules/exp_scenario/features")
local clusterio_api = require("modules/clusterio/api")
local community_details = require("modules/exp_scenario/config/community_details").config

local feature = Feature.register("greetings")

--- @param event EventData.on_player_joined_game
local function on_player_joined_game(event)
    local player = assert(game.get_player(event.player_index))
    player.print{ "exp_greetings.greet", community_details.community_name, community_details.discord }
end

--- Set your custom join message, or show it when no message is given
Commands.new("set-join-message", { "exp_greetings.description-set" })
    :optional("message", { "exp_greetings.arg-message" }, Commands.types.string_max_length(255))
    :enable_auto_concatenation()
    :add_aliases{ "join-message" }
    :add_flags{ feature = feature }
    :register(function(player, message)
        --- @cast message string?
        if message then
            clusterio_api.send_json("exp_scenario:join_message_set", { player_name = player.name, message = message })
            return Commands.status.success{ "exp_greetings.message-set" }
        end
        -- The instance plugin prints the message
        clusterio_api.send_json("exp_scenario:join_message_get", { player_name = player.name })
    end)

--- Removes your custom join message
Commands.new("remove-join-message", { "exp_greetings.description-remove" })
    :add_flags{ feature = feature }
    :register(function(player)
        clusterio_api.send_json("exp_scenario:join_message_set", { player_name = player.name })
        return Commands.status.success{ "exp_greetings.message-cleared" }
    end)

local e = defines.events

return feature:guard{
    events = {
        [e.on_player_joined_game] = on_player_joined_game,
    },
}
