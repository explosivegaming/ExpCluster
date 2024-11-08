--- Greets players on join
-- @data Greetings

local config = require("modules.exp_legacy.config.join_messages") --- @dep config.join_messages
local Commands = require("modules/exp_commands")

--- Stores the join message that the player have
local PlayerData = require("modules.exp_legacy.expcore.player_data") --- @dep expcore.player_data
local CustomMessages = PlayerData.Settings:combine("JoinMessage")
CustomMessages:set_metadata{
    permission = "command/join-message",
}

--- When a players data loads show their message
CustomMessages:on_load(function(player_name, player_message)
    local player = game.players[player_name]
    local custom_message = player_message or config[player_name]
    if custom_message then
        game.print(custom_message, { color = player.color })
    else
        player.print{ "join-message.greet", { "links.discord" } }
    end
end)

--- Set your custom join message
Commands.new("set-join-message", { "join-message.description-add" })
    :optional("message", false, Commands.types.string_max_length(255))
    :enable_auto_concatenation()
    :add_aliases{ "join-message" }
    :register(function(player, message)
        --- @cast message string?
        if message then
            CustomMessages:set(player, message)
            return Commands.status.success{ "join-message.message-set" }
        else
            return Commands.status.success{ "join-message.message-get", CustomMessages:get(player) }
        end
    end)

--- Removes your custom join message
Commands.new("remove-join-message", { "join-message.description-remove" })
    :register(function(player)
        CustomMessages:remove(player)
        return Commands.status.success{ "join-message.message-cleared" }
    end)
