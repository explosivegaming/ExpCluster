--[[-- ExpDiscord - Commands
Commands which link and unlink the player's Discord account
]]

local Commands = require("modules/exp_commands")

local Discord = require("modules/exp_discord")

--- Links your account to the Discord account which made the code, printed once the controller answers
Commands.new("link-discord", { "exp-discord_commands.description-link" })
    :optional("code", { "exp-discord_commands.arg-code" }, Commands.types.string)
    :add_aliases{ "link" }
    :register(function(player, code)
        --- @cast code string?
        if code then
            Discord.link(player, code)
        else
            Discord.get_link(player)
        end
    end)

--- Removes the link to your Discord account, printed once the controller answers
Commands.new("unlink-discord", { "exp-discord_commands.description-unlink" })
    :add_aliases{ "unlink" }
    :register(function(player)
        Discord.unlink(player)
    end)

-- Access the exports from other modules using require("modules/exp_discord")
return require("modules/exp_discord/control")
