--[[-- Commands Module - Kill
    - Adds a command that allows players to kill them selfs and others
    @commands Kill
]]

local Commands = require 'expcore.commands' --- @dep expcore.commands
local Roles = require 'expcore.roles' --- @dep expcore.roles
require 'config.expcore.command_general_parse'
require 'config.expcore.command_role_parse'

--- Kills yourself or another player.
-- @command kill
-- @tparam[opt=self] LuaPlayer player the player to kill, must be alive to be valid
Commands.new_command('kill', {'expcom-kill.description'}, 'Kills yourself or another player.')
:add_param('player', true, 'player-role-alive')
:set_defaults{player=function(player)
    -- default is the player unless they are dead
    if player.character and player.character.health > 0 then
        return player
    end
end}
:register(function(player, action_player)
    if not action_player then
        -- can only be nil if no player given and the user is dead
        return Commands.error{'expcom-kill.already-dead'}
    end
    if player == action_player then
        action_player.character.die()

    elseif Roles.player_allowed(player, 'command/kill/always') then
        action_player.character.die()

    else
        return Commands.error{'expcore-commands.unauthorized'}
    end
end)
