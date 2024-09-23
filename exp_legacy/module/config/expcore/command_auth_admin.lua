--- This is a very simple config file which adds a admin only auth function;
-- not much to change here its more so it can be enabled and disabled from ./config/file_loader.lua;
-- either way you can change the requirements to be "admin" if you wanted to
-- @config Commands-Auth-Admin

local Commands = require 'expcore.commands' --- @dep expcore.commands

-- luacheck:ignore 212/command
Commands.add_authenticator(function(player, command, tags, reject)
    if tags.admin_only then
        if player.admin then
            return true
        else
            return reject{'command-auth.admin-only'}
        end
    else
        return true
    end
end)