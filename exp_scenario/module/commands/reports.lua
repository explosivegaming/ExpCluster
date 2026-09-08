--[[-- Commands - Reports
Adds a commands that allow players to report other players
]]

local Commands = require("modules/exp_commands")
local parse_input = Commands.parse_input

local Roles = require("modules/exp_roles")
local player_has_permission = Roles.player_has_permission

local Reports = require("modules/exp_reports")

--- @param input string
--- @param player LuaPlayer
--- @return Commands.Status
--- @return LuaPlayer | LocalisedString
local function reportable_player(input, player)
    local success, status, result = parse_input(input, player, Commands.types.player)
    if not success then return status, result end
    --- @cast result LuaPlayer

    if player_has_permission(input, "exp_scenario.bypass.reports") then
        return Commands.status.invalid_input{ "exp-commands_reports.player-immune" }
    elseif player == input then
        return Commands.status.invalid_input{ "exp-commands_reports.self-report" }
    else
        return Commands.status.success(result)
    end
end

--- Reports a player and notifies admins, the outcome is printed once the controller answers
Commands.new("create-report", { "exp-commands_reports.description-create" })
    :argument("player", { "exp-commands_reports.arg-player-create" }, reportable_player)
    :argument("reason", { "exp-commands_reports.arg-reason" }, Commands.types.string)
    :enable_auto_concatenation()
    :add_aliases{ "report" }
    :register(function(player, other_player, reason)
        --- @cast other_player LuaPlayer
        --- @cast reason string
        Reports.create_report(player, other_player, reason)
    end)

--- Lists the reports against a player, or the number against every player, printed once the controller answers
Commands.new("get-reports", { "exp-commands_reports.description-get" })
    :optional("player", { "exp-commands_reports.arg-player-get" }, Commands.types.player)
    :add_aliases{ "reports" }
    :add_flags{ "admin_only" }
    :register(function(player, other_player)
        --- @cast other_player LuaPlayer?
        Reports.list_reports(player, other_player)
    end)

--- Clears all reports from a player or just the report from one player, printed once the controller answers
Commands.new("clear-reports", { "exp-commands_reports.description-clear" })
    :argument("player", { "exp-commands_reports.arg-player-clear" }, Commands.types.player)
    :optional("from-player", { "exp-commands_reports.arg-from-player" }, Commands.types.player)
    :add_flags{ "admin_only" }
    :register(function(player, other_player, from_player)
        --- @cast other_player LuaPlayer
        --- @cast from_player LuaPlayer?
        Reports.delete_reports(player, other_player, from_player and from_player.name)
    end)
