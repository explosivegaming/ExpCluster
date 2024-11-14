--[[-- Command Authorities - Roles
Adds a permission authority for exp roles
]]

local Commands = require("modules/exp_commands")
local add, allow, deny = Commands.add_permission_authority, Commands.status.success, Commands.status.unauthorised

local Roles = require("modules/exp_legacy/expcore/roles")
local player_allowed = Roles.player_allowed

local authorities = {}

--- If a command has the flag "character_only" then the command can only be used outside of remote view
authorities.exp_permission =
    add(function(player, command)
        if not player_allowed(player, command.flags.exp_permission or ("command/" .. command.name)) then
            return deny{ "exp-commands-authorities_role.deny" }
        else
            return allow()
        end
    end)

Roles.define_flag_trigger("is_system", function(player, state)
    if state then
        Commands.unlock_system_commands(player.name)
    else
        Commands.lock_system_commands(player.name)
    end
end)

return authorities
