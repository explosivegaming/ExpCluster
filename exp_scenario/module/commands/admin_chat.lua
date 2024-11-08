--[[-- Commands - Admin Chat
Adds a command that allows admins to talk in a private chat
]]

local Commands = require("modules/exp_commands")
local format_player_name = Commands.format_player_name_locale

--- Sends a message in chat that only admins can see
Commands.new("admin-chat", { "exp-commands_admin-chat.description" })
    :argument("message", { "exp-commands_admin-chat.arg-message" }, Commands.types.string)
    :enable_auto_concatenation()
    :add_aliases{ "ac" }
    :add_flags{ "admin_only" }
    :register(function(player, message)
        --- @cast message string
        local player_name = format_player_name(player)
        for _, next_player in ipairs(game.connected_players) do
            if next_player.admin then
                next_player.print{ "exp-commands_admin-chat.format", player_name, message }
            end
        end
    end)
