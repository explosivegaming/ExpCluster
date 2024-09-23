--[[-- Commands Module - Spectate
    - Adds commands relating to spectate and follow
    @commands Spectate
]]

local Spectate = require 'modules.control.spectate' --- @dep modules.control.spectate
local Commands = require 'expcore.commands' --- @dep expcore.commands
require 'config.expcore.command_general_parse'

--- Toggles spectator mode for the caller
-- @command spectate
Commands.new_command('spectate', {'expcom-spectate.description-spectate'}, 'Toggles spectator mode')
:register(function(player)
    if Spectate.is_spectating(player) then
        Spectate.stop_spectate(player)

    else
        Spectate.start_spectate(player)
    end
end)

--- Enters follow mode for the caller, following the given player.
-- @command follow
-- @tparam LuaPlayer player The player that will be followed
Commands.new_command('follow', {'expcom-spectate.description-follow'}, 'Start following a player in spectator')
:add_alias('f')
:add_param('player', false, 'player-online')
:register(function(player, action_player)
    if player == action_player then
       return Commands.error{'expcom-spectate.follow-self'}

    else
        Spectate.start_follow(player, action_player)
    end
end)
