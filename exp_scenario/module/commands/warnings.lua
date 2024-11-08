--[[-- Commands - Warnings
Adds a commands that allow admins to warn other players
]]

local Commands = require("modules/exp_commands")
local format_player_name = Commands.format_player_name_locale

local Warnings = require("modules.exp_legacy.modules.control.warnings") --- @dep modules.control.warnings
local config = require("modules.exp_legacy.config.warnings") --- @dep config.warnings

--- Gives a warning to a player; may lead to automatic script action.
Commands.new("create-warning", { "exp-commands_warnings.description-create" })
    :argument("player", { "exp-commands_warnings.arg-player-create" }, Commands.types.lower_role_player)
    :argument("reason", { "exp-commands_warnings.arg-reason" }, Commands.types.string)
    :enable_auto_concatenation()
    :add_aliases{ "warn" }
    :add_flags{ "admin_only" }
    :register(function(player, other_player, reason)
        --- @cast other_player LuaPlayer
        --- @cast reason string
        Warnings.add_warning(other_player, player.name, reason)
        local player_name = format_player_name(player) 
        local other_player_name = format_player_name(other_player)
        game.print{ "exp-commands_warnings.create", other_player_name, player_name, reason }
    end)

--- Gets a list of all warnings that a player has on them. If no player then lists all players and the number of warnings on them.
Commands.new("get-warnings", { "exp-commands_warnings.description-get" })
    :optional("player", { "exp-commands_warnings.arg-player-get" }, Commands.types.player)
    :add_aliases{ "warnings" }
    :add_flags{ "admin_only" }
    :register(function(player, other_player)
        --- @cast other_player LuaPlayer?
        if other_player then
            local warnings = Warnings.get_warnings(player)
            local script_warnings = Warnings.get_script_warnings(player)
            local other_player_name = format_player_name(other_player)
            Commands.print{ "exp-commands_warnings.player-title", other_player_name, #warnings, #script_warnings, config.temp_warning_limit }
            for _, warning in pairs(warnings) do
                local by_player_name_formatted = format_player_name(warning.by_player_name)
                Commands.print{ "exp-commands_warnings.list-element-player", by_player_name_formatted, warning.reason }
            end
        else
            local warnings = Warnings.user_warnings:get_all()
            local script_warnings = Warnings.user_script_warnings
            Commands.print{ "exp-commands_warnings.warnings-title" }
            for player_name, player_warnings in pairs(warnings) do
                local player_name_formatted = format_player_name(player_name)
                local script_warning_count = script_warnings[player_name] and #script_warnings[player_name] or 0
                Commands.print{ "exp-commands_warnings.list-element", player_name_formatted, #player_warnings, script_warning_count, config.temp_warning_limit }
            end
            for player_name, player_warnings in pairs(script_warnings) do
                if not warnings[player_name] then
                    local player_name_formatted = format_player_name(player_name)
                    Commands.print{ "exp-commands_warnings.list-element", player_name_formatted, 0, #player_warnings, config.temp_warning_limit }
                end
            end
        end
    end)

--- Clears all warnings from a player
Commands.new("clear-warnings", { "exp-commands_warnings.description-clear" })
    :argument("player", { "exp-commands_warnings.arg-player-clear" }, Commands.types.player)
    :add_flags{ "admin_only" }
    :register(function(player, other_player)
        --- @cast other_player LuaPlayer
        Warnings.clear_warnings(other_player, player.name)
        Warnings.clear_script_warnings(other_player)
        local player_name = format_player_name(player)
        local other_player_name = format_player_name(other_player)
        game.print{ "exp-commands_warnings.cleared", other_player_name, player_name }
    end)

--- Clears all script warnings from a player
Commands.new("clear-script-warnings", { "exp-commands_warnings.description-clear-script" })
    :argument("player", { "exp-commands_warnings.arg-player-clear" }, Commands.types.player)
    :add_flags{ "admin_only" }
    :register(function(player, other_player)
        --- @cast other_player LuaPlayer
        Warnings.clear_script_warnings(other_player)
        local player_name = format_player_name(player)
        local other_player_name = format_player_name(other_player)
        game.print{ "exp-commands_warnings.cleared-script", other_player_name, player_name }
    end)

--- Clears the last warning that was given to a player
Commands.new("clear-last-warnings", { "exp-commands_warnings.description-clear-last" })
    :argument("player", { "exp-commands_warnings.arg-player-clear" }, Commands.types.player)
    :add_flags{ "admin_only" }
    :register(function(player, other_player)
        --- @cast other_player LuaPlayer
        Warnings.remove_warning(other_player, player.name)
        local player_name = format_player_name(player)
        local other_player_name = format_player_name(other_player)
        game.print{ "exp-commands_warnings.cleared-last", other_player_name, player_name }
    end)
