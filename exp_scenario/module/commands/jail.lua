--[[-- Commands - Jail
Adds a commands that allow admins to jail and unjail
]]

local Commands = require("modules/exp_commands")
local format_player_name = Commands.format_player_name_locale

local Jail = require("modules.exp_legacy.modules.control.jail") --- @dep modules.control.jail

--- Puts a player into jail and removes all other roles.
Commands.new("jail", { "exp-commands_jail.description" })
    :argument("player", { "exp-commands_jail.arg-player" }, Commands.types.lower_role_player)
    :optional("reason", { "exp-commands_jail.arg-reason" }, Commands.types.string)
    :enable_auto_concatenation()
    :register(function(player, other_player, reason)
        --- @cast other_player LuaPlayer
        --- @cast reason string?
        if not reason then
            reason = "None Given."
        end

        local player_name = format_player_name(player)
        local other_player_name = format_player_name(other_player)
        if Jail.jail_player(other_player, player.name, reason) then
            game.print{ "exp-commands_jail.jailed", other_player_name, player_name, reason }
        else
            return Commands.status.error{ "exp-commands_jail.already-jailed", other_player_name }
        end
    end)

--- Removes a player from jail and restores their old roles.
Commands.new("unjail", { "exp-commands_unjail.description" })
    :argument("player", { "exp-commands_unjail.arg-player" }, Commands.types.lower_role_player)
    :register(function(player, other_player)
        --- @cast other_player LuaPlayer
        local player_name = format_player_name(player)
        local other_player_name = format_player_name(other_player)
        if Jail.unjail_player(other_player, player.name) then
            game.print{ "exp-commands_unjail.unjailed", other_player_name, player_name }
        else
            return Commands.status.error{ "exp-commands_unjail.not-jailed", other_player_name }
        end
    end)
