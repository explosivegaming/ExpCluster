--- This config for command auth allows commands to be globally enabled and disabled during runtime;
-- this config adds Commands.disable and Commands.enable to enable and disable commands for all users
-- @config Commands-Auth-Runtime-Disable

local Commands = require("modules.exp_legacy.expcore.commands") --- @dep expcore.commands
local Storage = require("modules/exp_util/storage")

local disabled_commands = {}
Storage.register(disabled_commands, function(tbl)
    disabled_commands = tbl
end)

--- Stops a command from be used by any one
-- @tparam string command_name the name of the command to disable
function Commands.disable(command_name)
    disabled_commands[command_name] = true
end

--- Allows a command to be used again after disable was used
-- @tparam string command_name the name of the command to enable
function Commands.enable(command_name)
    disabled_commands[command_name] = nil
end

-- luacheck:ignore 212/player 212/tags
Commands.add_authenticator(function(player, command, tags, reject)
    if disabled_commands[command] then
        return reject{'command-auth.command-disabled'}
    else
        return true
    end
end)