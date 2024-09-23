--- Greets players on join
-- @data Greetings

local config = require 'config.join_messages' --- @dep config.join_messages
local Commands = require 'expcore.commands' ---@dep expcore.commands
require 'config.expcore.command_general_parse'

--- Stores the join message that the player have
local PlayerData = require 'expcore.player_data' --- @dep expcore.player_data
local CustomMessages = PlayerData.Settings:combine('JoinMessage')
CustomMessages:set_metadata{
    permission = 'command/join-message'
}

--- When a players data loads show their message
CustomMessages:on_load(function(player_name, player_message)
    local player = game.players[player_name]
    local custom_message = player_message or config[player_name]
    if custom_message then
        game.print(custom_message, player.color)
    else
        player.print{'join-message.greet', {'links.discord'}}
    end
end)

--- Set your custom join message
-- @command join-message
-- @tparam string message The custom join message that will be used
Commands.new_command('join-message', {'expcom-join-message.description-msg'}, 'Sets your custom join message')
:add_param('message', false, 'string-max-length', 255)
:enable_auto_concat()
:register(function(player, message)
    if not player then return end
    CustomMessages:set(player, message)
    return {'join-message.message-set'}
end)

Commands.new_command('join-message-clear', {'expcom-join-message.description-clr'}, 'Clear your join message')
:register(function(player)
    if not player then return end
    CustomMessages:remove(player)
    return {'join-message.message-cleared'}
end)
