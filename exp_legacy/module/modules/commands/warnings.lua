--[[-- Commands Module - Warnings
    - Adds a commands that allow admins to warn other players
    @commands Warnings
]]

local Commands = require 'expcore.commands' --- @dep expcore.commands
local Warnings = require 'modules.control.warnings' --- @dep modules.control.warnings
local format_chat_player_name = _C.format_chat_player_name --- @dep expcore.common
local config = require 'config.warnings' --- @dep config.warnings
require 'config.expcore.command_role_parse'

--- Gives a warning to a player; may lead to automatic script action.
-- @command give-warning
-- @tparam LuaPlayer player the player the will recive a warning
-- @tparam string reason the reason the player is being given a warning
Commands.new_command('give-warning', {'expcom-warnings.description-give'}, 'Gives a warning to a player; may lead to automatic script action.')
:add_param('player', false, 'player-role')
:add_param('reason', false)
:add_alias('warn')
:enable_auto_concat()
:register(function(player, action_player, reason)
    Warnings.add_warning(action_player, player.name, reason)
    local action_player_name_color = format_chat_player_name(action_player)
    local by_player_name_color = format_chat_player_name(player)
    game.print{'expcom-warnings.received', action_player_name_color, by_player_name_color, reason}
end)

--- Gets the number of warnings a player has. If no player then lists all players and the number of warnings they have.
-- @command get-warnings
-- @tparam[opt=list] LuaPlayer player the player to get the warning for, if nil all players are listed
Commands.new_command('get-warnings', {'expcom-warnings.description-get'}, 'Gets the number of warnings a player has. If no player then lists all players and the number of warnings they have.')
:add_param('player', true, 'player')
:add_alias('warnings', 'list-warnings')
:register(function(_, player)
    if player then
        local warnings = Warnings.get_warnings(player)
        local script_warnings = Warnings.get_script_warnings(player)
        local player_name_color = format_chat_player_name(player)
        Commands.print{'expcom-warnings.player', player_name_color, #warnings, #script_warnings, config.temp_warning_limit}
        for _, warning in ipairs(warnings) do
            Commands.print{'expcom-warnings.player-detail', format_chat_player_name(warning.by_player_name), warning.reason}
        end
    else
        local rtn = {}
        local user_script_warnings = Warnings.user_script_warnings
        for player_name, warnings in pairs(Warnings.user_warnings:get_all()) do
            rtn[player_name] = {#warnings, 0}
        end
        for player_name, warnings in pairs(user_script_warnings) do
            if not rtn[player_name] then
                rtn[player_name] = {0, 0}
            end
            rtn[player_name][2] = #warnings
        end
        Commands.print{'expcom-warnings.list-title'}
        for player_name, warnings in pairs(rtn) do
            local player_name_color = format_chat_player_name(player_name)
            Commands.print{'expcom-warnings.list', player_name_color, warnings[1], warnings[2], config.temp_warning_limit}
        end
    end
end)

--- Clears all warnings (and script warnings) from a player
-- @command clear-warnings
-- @tparam LuaPlayer player the player to clear the warnings from
Commands.new_command('clear-warnings', {'expcom-warnings.description-clear'}, 'Clears all warnings (and script warnings) from a player')
:add_param('player', false, 'player')
:register(function(player, action_player)
    Warnings.clear_warnings(action_player, player.name)
    Warnings.clear_script_warnings(action_player)
    local action_player_name_color = format_chat_player_name(action_player)
    local by_player_name_color = format_chat_player_name(player)
    game.print{'expcom-warnings.cleared', action_player_name_color, by_player_name_color}
end)
