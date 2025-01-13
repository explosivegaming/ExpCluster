--[[-- Command Module - Default permission authorities
The default permission authorities controlled by the flags: admin_only, system_only, no_rcon, disabled

@usage-- Unlock system commands for debugging purposes
/c require("modules/exp-commands").unlock_system_commands(game.player)

@usage-- Disable a command for all players because it is not functioning correctly
/c require("modules/exp-commands").disable("my-command")
]]

local Storage = require("modules/exp_util/storage")

local Commands = require("modules/exp_commands") --- @class Commands
local add, allow, deny = Commands.add_permission_authority, Commands.status.success, Commands.status.unauthorised

local authorities = {}

local system_players = {} --- @type table<string, boolean>
local disabled_commands = {} --- @type table<string, boolean>
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
function Commands.get_system_players()
    return table.get_keys(system_players)
end

--- Check if a player is a system user
function Commands.is_system_player(player_name)
    return system_players[player_name] or false
end

--- Stops a command from be used by any one
--- @param command_name string The name of the command to disable
function Commands.disable_command(command_name)
    disabled_commands[command_name] = true
end

--- Allows a command to be used again after disable was used
--- @param command_name string The name of the command to enable
function Commands.enable_command(command_name)
    disabled_commands[command_name] = nil
end

--- Get a list of all disabled commands_help
function Commands.get_disabled_commands()
    return table.get_keys(disabled_commands)
end

--- Check if a player is a system user
function Commands.is_disabled_command(command_name)
    return disabled_commands[command_name] or false
end

--- If a command has the flag "character_only" then the command can only be used outside of remote view
authorities.character_only =
    add(function(player, command)
        if command.flags.character_only and player.controller_type ~= defines.controllers.character then
            return deny{ "exp-commands-authorities.character-only" }
        else
            return allow()
        end
    end)

--- If a command has the flag "remote_only" then the command can only be used inside of remote view
authorities.remote_only =
    add(function(player, command)
        if command.flags.remote_only and player.controller_type ~= defines.controllers.remote then
            return deny{ "exp-commands-authorities.remote-only" }
        else
            return allow()
        end
    end)

--- If a command has the flag "admin_only" then only admins can use the command
authorities.admin_only =
    add(function(player, command)
        if command.flags.admin_only and not player.admin then
            return deny{ "exp-commands-authorities.admin-only" }
        else
            return allow()
        end
    end)

--- If a command has the flag "system_only" then only rcon and system users can use the command
authorities.system_only =
    add(function(player, command)
        if command.flags.system_only and not system_players[player.name] then
            return deny{ "exp-commands-authorities.system-only" }
        else
            return allow()
        end
    end)

--- If Commands.disable_command was called then only rcon and system users can use the command
authorities.disabled =
    add(function(player, command)
        if disabled_commands[command.name] and not system_players[player.name] then
            return deny{ "exp-commands-authorities.disabled" }
        else
            return allow()
        end
    end)

return authorities
