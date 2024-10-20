
local Commands = require("modules/exp_commands")
local add, allow, deny = Commands.add_permission_authority, Commands.status.success, Commands.status.unauthorised

local Roles = require("modules/exp_legacy/expcore/roles")

local authorities = {}

--- If a command has the flag "character_only" then the command can only be used outside of remote view
authorities.exp_permission =
    add(function(player, command)
        if not Roles.player_allowed(player, command.flags.exp_permission or ("command/" .. command)) then
            return deny{ "exp-commands-authorities_role.deny" }
        else
            return allow()
        end
    end)

return authorities
