--[[-- Commands Module - Last location
    - Adds a command that will return the last location of a player
    @commands LastLocation
]]

local Commands = require 'expcore.commands' --- @dep expcore.commands
local format_chat_player_name = _C.format_chat_player_name --- @dep expcore.common
require 'config.expcore.command_general_parse'

--- Get the last location of a player.
-- @command last-location
-- @tparam LuaPlayer player the player that you want a location of
Commands.new_command('last-location', {'expcom-lastlocation.description'}, 'Sends you the last location of a player')
:add_alias('location')
:add_param('player', false, 'player')
:register(function(_, action_player)
    local action_player_name_color = format_chat_player_name(action_player)
    return Commands.success{'expcom-lastlocation.response', action_player_name_color, string.format('%.1f', action_player.position.x), string.format('%.1f', action_player.position.y)}
end)
