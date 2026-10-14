--[[-- ExpDiscordAuth - Commands
Commands which link and unlink the player's Discord account
]]

local Commands = require("modules/exp_commands")

local Discord = require("modules/exp_discord_auth")

--- @class ExpDiscordAuth.commands
local commands = {}

--- Links your account to the Discord account which made the code, printed once the controller answers
commands.link_discord = Commands.new("link-discord", { "exp-discord-auth_commands.description-link" })
    :optional("code", { "exp-discord-auth_commands.arg-code" }, Commands.types.string)
    :add_aliases{ "link" }
    :register(function(player, code)
        --- @cast code string?
        if code then
            Discord.link(player, code)
        else
            Discord.get_linked(player)
        end
    end)

--- Removes the link to your Discord account, printed once the controller answers
commands.unlink_discord = Commands.new("unlink-discord", { "exp-discord-auth_commands.description-unlink" })
    :add_aliases{ "unlink" }
    :register(function(player)
        Discord.unlink(player)
    end)

return {
    commands = commands,
}
