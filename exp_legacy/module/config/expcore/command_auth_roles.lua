--- This will make commands only work if the role has been allowed it in the role config
-- @config Commands-Auth-Roles

local Commands = require 'expcore.commands' --- @dep expcore.commands
local Roles = require 'expcore.roles' --- @dep expcore.roles

-- luacheck:ignore 212/tags
Commands.add_authenticator(function(player, command, tags, reject)
    if Roles.player_allowed(player,'command/'..command) then
        return true
    else
        return reject()
    end
end)