--[[-- Adds some parse functions that can be used with the role system
@config Commands-Parse-Roles
@usage Adds Parses:
    role
    player-role
    player-role-online
    player-role-alive
]]

local Commands = require 'expcore.commands' --- @dep expcore.commands
local Roles = require 'expcore.roles' --- @dep expcore.roles
local auto_complete = _C.auto_complete --- @dep expcore.common
require 'config.expcore.command_general_parse'

-- luacheck:ignore 212/player
Commands.add_parse('role',function(input, player, reject)
    if not input then return end
    local roles = Roles.config.order
    local rev_roles = {}
    for i=#roles, 1,-1 do
        table.insert(rev_roles, roles[i])
    end
    local role = auto_complete(rev_roles, input)
    role = Roles.get_role_by_name(role)
    if not role then
        return reject{'expcore-role.reject-role'}
    else
        return role
    end
end)

Commands.add_parse('player-role',function(input, player, reject)
    local input_player = Commands.parse('player',input, player, reject)
    if not input_player then return end -- nil check
    local player_highest = Roles.get_player_highest_role(player)
    local input_player_highest = Roles.get_player_highest_role(input_player)
    if player_highest.index < input_player_highest.index then
        return input_player
    else
        return reject{'expcore-roles.reject-player-role'}
    end
end)

Commands.add_parse('player-role-online',function(input, player, reject)
    local input_player = Commands.parse('player-role',input, player, reject)
    if not input_player then return end -- nil check
    return Commands.parse('player-online',input_player.name, player, reject)
end)

Commands.add_parse('player-role-alive',function(input, player, reject)
    local input_player = Commands.parse('player-role',input, player, reject)
    if not input_player then return end -- nil check
    return Commands.parse('player-alive',input_player.name, player, reject)
end)