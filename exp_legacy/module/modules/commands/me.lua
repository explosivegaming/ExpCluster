--[[-- Commands Module - Me
    - Adds a command that adds * around your message in the chat
    @commands Me
]]

local Commands = require 'expcore.commands' --- @dep expcore.commands

--- Sends an action message in the chat
-- @command me
-- @tparam string action the action that follows your name in chat
Commands.new_command('me', {'expcom-me.description'}, 'Sends an action message in the chat')
:add_param('action', false)
:enable_auto_concat()
:register(function(player, action)
    local player_name = player and player.name or '<Server>'
    game.print(string.format('* %s %s *', player_name, action), player.chat_color)
end)
