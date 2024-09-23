--[[-- Commands Module - Reports
    - Adds a commands that allow players to report other players
    @commands Reports
]]

local Roles = require 'expcore.roles' --- @dep expcore.roles
local Commands = require 'expcore.commands' --- @dep expcore.commands
local Reports = require 'modules.control.reports' --- @dep modules.control.reports
local format_chat_player_name = _C.format_chat_player_name--- @dep expcore.common
require 'config.expcore.command_general_parse'

--- Print a message to all players who match the value of admin
local function print_to_players(admin, message)
    for _, player in ipairs(game.connected_players) do
        if player.admin == admin then
            player.print(message)
        end
    end
end

--- Reports a player and notifies moderators
-- @command report
-- @tparam LuaPlayer player the player to report, some players are immune
-- @tparam string reason the reason the player is being reported
Commands.new_command('report', {'expcom-report.description-report'}, 'Reports a player and notifies moderators')
:add_param('player', false, function(input, player, reject)
    input = Commands.parse('player', input, player, reject)
    if not input then return end
    if Roles.player_has_flag(input, 'report-immune') then
        return reject{'expcom-report.player-immune'}
    elseif player == input then
        return reject{'expcom-report.self-report'}
    else
        return input
    end
end)
:add_param('reason', false)
:add_alias('report-player')
:enable_auto_concat()
:register(function(player, action_player, reason)
    local action_player_name_color = format_chat_player_name(action_player)
    local by_player_name_color = format_chat_player_name(player)
    if Reports.report_player(action_player, player.name, reason) then
        print_to_players(false, {'expcom-report.non-admin', action_player_name_color, reason})
        print_to_players(true,  {'expcom-report.admin', action_player_name_color, by_player_name_color, reason})
    else
        return Commands.error{'expcom-report.already-reported'}
    end
end)

--- Gets a list of all reports that a player has on them. If no player then lists all players and the number of reports on them.
-- @command get-reports
-- @tparam LuaPlayer player the player to get the report for
Commands.new_command('get-reports', {'expcom-report.description-get-reports'}, 'Gets a list of all reports that a player has on them. If no player then lists all players and the number of reports on them.')
:add_param('player', true, 'player')
:add_alias('reports', 'list-reports')
:register(function(_, player)
    if player then
        local reports = Reports.get_reports(player)
        local player_name_color = format_chat_player_name(player)
        Commands.print{'expcom-report.player-report-title', player_name_color}
        for player_name, reason in pairs(reports) do
            local by_player_name_color = format_chat_player_name(player_name)
            Commands.print{'expcom-report.list', by_player_name_color, reason}
        end
    else
        local user_reports = Reports.user_reports
        Commands.print{'expcom-report.player-count-title'}
        for player_name in pairs(user_reports) do
            local player_name_color = format_chat_player_name(player_name)
            local report_count = Reports.count_reports(player_name)
            Commands.print{'expcom-report.list', player_name_color, report_count}
        end
    end
end)

--- Clears all reports from a player or just the report from one player.
-- @command clear-reports
-- @tparam LuaPlayer player the player to clear the report(s) from
-- @tparam[opt=all] LuaPlayer from-player remove only the report made by this player
Commands.new_command('clear-reports', {'expcom-report.description-clear-reports'}, 'Clears all reports from a player or just the report from one player.')
:add_param('player', false, 'player')
:add_param('from-player', true, 'player')
:register(function(player, action_player, from_player)
    if from_player then
        if not Reports.remove_report(action_player, from_player.name, player.name) then
            return Commands.error{'expcom-report.not-reported'}
        end
    else
        if not Reports.remove_all(action_player, player.name) then
            return Commands.error{'expcom-report.not-reported'}
        end
    end
    local action_player_name_color = format_chat_player_name(action_player)
    local by_player_name_color = format_chat_player_name(player)
    game.print{'expcom-report.removed', action_player_name_color, by_player_name_color}
end)
