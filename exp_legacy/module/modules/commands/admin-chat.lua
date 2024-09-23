--[[-- Commands Module - Admin Chat
    - Adds a command that allows admins to talk in a private chat
    @commands Admin-Chat
]]

local Commands = require 'expcore.commands' --- @dep expcore.commands
local format_chat_player_name = _C.format_chat_player_name --- @dep expcore.common
require 'config.expcore.command_general_parse'

--- Sends a message in chat that only admins can see
-- @command admin-chat
-- @tparam string message the message to send in the admin chat
Commands.new_command('admin-chat', {'expcom-admin-chat.description'}, 'Sends a message in chat that only admins can see.')
:add_param('message', false)
:enable_auto_concat()
:set_flag('admin_only')
:add_alias('ac')
:register(function(player, message)
    local player_name_colour = format_chat_player_name(player)

    for _, return_player in pairs(game.connected_players) do
        if return_player.admin then
            return_player.print{'expcom-admin-chat.format', player_name_colour, message}
        end
    end
    return Commands.success -- prevents command complete message from showing
end)
