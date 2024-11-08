--[[-- Commands - Reports
Adds a commands that allow players to report other players
]]

local Commands = require("modules/exp_commands")
local format_player_name = Commands.format_player_name_locale
local parse_input = Commands.parse_input

local Roles = require("modules.exp_legacy.expcore.roles")
local player_has_flag = Roles.player_has_flag

local Reports = require("modules.exp_legacy.modules.control.reports") --- @dep modules.control.reports

--- @type Commands.InputParser
local function reportable_player(input, player)
    local success, status, result = parse_input(input, player, Commands.types.player)
    if not success then return status, result end
    --- @cast result LuaPlayer

    if player_has_flag(input, "report-immune") then
        return Commands.status.invalid_input{ "exp-commands_reports.player-immune" }
    elseif player == input then
        return Commands.status.invalid_input{ "exp-commands_reports.self-report" }
    else
        return Commands.status.success(result)
    end
end

--- Reports a player and notifies admins
Commands.new("create-report", { "exp-commands_reports.description-create" })
    :argument("player", { "exp-commands_reports.arg-player-create" }, reportable_player)
    :argument("reason", { "exp-commands_reports.arg-reason" }, Commands.types.string)
    :enable_auto_concatenation()
    :add_aliases{ "report" }
    :register(function(player, other_player, reason)
        --- @cast other_player LuaPlayer
        --- @cast reason string
        local player_name = format_player_name(player)
        local other_player_name = format_player_name(other_player)
        if Reports.report_player(other_player, player.name, reason) then
            local user_message = { "exp-commands_reports.response", other_player_name, reason }
            local admin_message = { "exp-commands_reports.response-admin", other_player_name, player_name, reason }
            for _, player in ipairs(game.connected_players) do
                if player.admin then
                    player.print(admin_message)
                else
                    player.print(user_message)
                end
            end
        else
            return Commands.status.invalid_input{ "exp-commands_reports.already-reported" }
        end
    end)

--- Gets a list of all reports that a player has on them. If no player then lists all players and the number of reports on them.
Commands.new("get-reports", { "exp-commands_reports.description-get" })
    :optional("player", { "exp-commands_reports.arg-player-get" }, Commands.types.player)
    :add_aliases{ "reports" }
    :add_flags{ "admin_only" }
    :register(function(player, other_player)
        --- @cast other_player LuaPlayer?
        if other_player then
            local reports = Reports.get_reports(other_player)
            local other_player_name = format_player_name(other_player)
            Commands.print{ "exp-commands_reports.player-title", other_player_name, #reports }
            for by_player_name, reason in pairs(reports) do
                local by_player_name_formatted = format_player_name(by_player_name)
                Commands.print{ "exp-commands_reports.list-element", by_player_name_formatted, reason }
            end
        else
            local reports = Reports.user_reports
            Commands.print{ "exp-commands_reports.reports-title" }
            for player_name in pairs(reports) do
                local player_name_formatted = format_player_name(player_name)
                local report_count = Reports.count_reports(player_name)
                Commands.print{ "exp-commands_reports.list-element", player_name_formatted, report_count }
            end
        end
    end)

--- Clears all reports from a player or just the report from one player.
Commands.new("clear-reports", { "exp-commands_reports.description-clear" })
    :argument("player", { "exp-commands_reports.arg-player-clear" }, Commands.types.player)
    :optional("from-player", { "exp-commands_reports.arg-from-player" }, Commands.types.player)
    :add_flags{ "admin_only" }
    :register(function(player, other_player, from_player)
        --- @cast other_player LuaPlayer
        --- @cast from_player LuaPlayer?
        local player_name = format_player_name(player)
        local other_player_name = format_player_name(other_player)
        if from_player then
            if not Reports.remove_report(other_player, from_player.name, player.name) then
                local from_player_name = format_player_name(other_player)
                return Commands.status.invalid_input{ "exp-commands_reports.not-reported-by", from_player_name }
            else
                game.print{ "exp-commands_reports.removed", other_player_name, player_name }
                return Commands.status.success()
            end
        else
            if not Reports.remove_all(other_player, player.name) then
                return Commands.status.invalid_input{ "exp-commands_reports.not-reported" }
            else
                game.print{ "exp-commands_reports.removed-all", other_player_name, player_name }
                return Commands.status.success()
            end
        end
    end)
