--[[-- Command Module - Default permission authorities
The default permission authorities controlled by the flags: admin_only, system_only, no_rcon, disabled

@usage-- Unlock system commands for debugging purposes
/c require("modules/exp-commands").unlock_system_commands(game.player)

@usage-- Disable a command for all players because it is not functioning correctly
/c require("modules/exp-commands").disable("my-command")
]]

local Storage = require("modules/exp_util/storage")
local Commands = require("modules/exp_commands")
local add, allow, deny = Commands.add_permission_authority, Commands.status.success, Commands.status.unauthorised

local authorities = {}

local system_players = {}
local disabled_commands = {}
Storage.register({
    system_players,
    disabled_commands,
}, function(tbl)
    system_players = tbl[1]
    disabled_commands = tbl[2]
end)

--- Allow a player access to system commands, use for debug purposes only
--- @param player_name string? The name of the player to give access to, default is the current player
function Commands.unlock_system_commands(player_name)
    system_players[player_name or game.player.name] = true
end

--- Remove access from system commands for a player, use for debug purposes only
--- @param player_name string? The name of the player to give access to, default is the current player
function Commands.lock_system_commands(player_name)
    system_players[player_name or game.player.name] = nil
end

--- Get a list of all players who have system commands unlocked
function Commands.get_system_command_players()
    return table.get_keys(system_players)
end

--- Stops a command from be used by any one
--- @param command_name string The name of the command to disable
function Commands.disable(command_name)
    disabled_commands[command_name] = true
end

--- Allows a command to be used again after disable was used
--- @param command_name string The name of the command to enable
function Commands.enable(command_name)
    disabled_commands[command_name] = nil
end

--- Get a list of all players who have system commands unlocked
function Commands.get_disabled_commands()
    return table.get_keys(disabled_commands)
end

--- If a command has the flag "admin_only" then only admins can use the command#
authorities.admin_only =
    add(function(player, command)
        if command.flags.admin_only and not player.admin then
            return deny{ "exp-commands-permissions.admin-only" }
        else
            return allow()
        end
    end)

--- If a command has the flag "system_only" then only rcon connections can use the command
authorities.system_only =
    add(function(player, command)
        if command.flags.system_only and not system_players[player.name] then
            return deny{ "exp-commands-permissions.system-only" }
        else
            return allow()
        end
    end)

--- If Commands.disable was called then no one can use the command
authorities.disabled =
    add(function(_player, command)
        if disabled_commands[command.name] then
            return deny{ "exp-commands-permissions.disabled" }
        else
            return allow()
        end
    end)

return authorities
