--[[-- Control - Greetings
Greets players when they join, players can set a message shown to everyone instead
]]

local Commands = require("modules/exp_commands")
local community_details = require("modules/exp_scenario/config/community_details").config

local PlayerData = require("modules.exp_legacy.expcore.player_data")
local CustomMessages = PlayerData.Settings:combine("JoinMessage")
CustomMessages:set_metadata{
    permission = "exp_scenario.command.set_join_message",
}

--- Show the message of a player once their data loads, or greet them
CustomMessages:on_load(function(player_name, player_message)
    local player = assert(game.get_player(player_name))
    if player_message then
        game.print(player_message, { color = player.color })
    else
        player.print{ "exp_greetings.greet", community_details.community_name, community_details.discord }
    end
end)

--- Set your custom join message
Commands.new("set-join-message", { "exp_greetings.description-set" })
    :optional("message", { "exp_greetings.arg-message" }, Commands.types.string_max_length(255))
    :enable_auto_concatenation()
    :add_aliases{ "join-message" }
    :register(function(player, message)
        --- @cast message string?
        if message then
            CustomMessages:set(player, message)
            return Commands.status.success{ "exp_greetings.message-set" }
        else
            return Commands.status.success{ "exp_greetings.message-get", CustomMessages:get(player) or "" }
        end
    end)

--- Removes your custom join message
Commands.new("remove-join-message", { "exp_greetings.description-remove" })
    :register(function(player)
        CustomMessages:remove(player)
        return Commands.status.success{ "exp_greetings.message-cleared" }
    end)

return {}
