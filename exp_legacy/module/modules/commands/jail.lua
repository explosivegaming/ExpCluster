--[[-- Commands Module - Jail
    - Adds a commands that allow admins to jail and unjail
    @commands Jail
]]

local Commands = require 'expcore.commands' --- @dep expcore.commands
local Jail = require 'modules.control.jail' --- @dep modules.control.jail
local format_chat_player_name = _C.format_chat_player_name --- @dep expcore.common
require 'config.expcore.command_role_parse'

--- Puts a player into jail and removes all other roles.
-- @command jail
-- @tparam LuaPlayer player the player that will be jailed
-- @tparam[opt] string reason the reason why the player is being jailed
Commands.new_command('jail', {'expcom-jail.description-jail'}, 'Puts a player into jail and removes all other roles.')
:add_param('player', false, 'player-role')
:add_param('reason', true)
:enable_auto_concat()
:register(function(player, action_player, reason)
    reason = reason or 'Non Given.'
    local action_player_name_color = format_chat_player_name(action_player)
    local by_player_name_color = format_chat_player_name(player)
    local player_name = player and player.name or '<server>'
    if Jail.jail_player(action_player, player_name, reason) then
        game.print{'expcom-jail.give', action_player_name_color, by_player_name_color, reason}
    else
        return Commands.error{'expcom-jail.already-jailed', action_player_name_color}
    end
end)

--- Removes a player from jail.
-- @command unjail
-- @tparam LuaPlayer the player that will be unjailed
Commands.new_command('unjail', {'expcom-jail.description-unjail'}, 'Removes a player from jail.')
:add_param('player', false, 'player-role')
:add_alias('clear-jail', 'remove-jail')
:enable_auto_concat()
:register(function(player, action_player)
    local action_player_name_color = format_chat_player_name(action_player)
    local by_player_name_color = format_chat_player_name(player)
    local player_name = player and player.name or '<server>'
    if Jail.unjail_player(action_player, player_name) then
        game.print{'expcom-jail.remove', action_player_name_color, by_player_name_color}
    else
        return Commands.error{'expcom-jail.not-jailed', action_player_name_color}
    end
end)
