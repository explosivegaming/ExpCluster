--[[-- Commands - Me
Adds a command that adds * around your message in the chat
]]

local Commands = require("modules/exp_commands")
local format_text = Commands.format_rich_text_color_locale

--- Sends an action message in the chat
Commands.new("me", { "exp-commands_me.description" })
    :argument("action", { "exp-commands_me.arg-action" }, Commands.types.string)
    :enable_auto_concatenation()
    :register(function(player, action)
        game.print(format_text({ "exp-commands_me.response", player.name, action, }, player.chat_color))
    end)
