--[[-- Control - Chat Auto Reply
Adds auto replies to chat messages, as well as chat commands
]]

local Roles = require("modules.exp_legacy.expcore.roles")
local config = require("modules.exp_legacy.config.chat_reply")
local prefix = config.command_prefix
local prefix_len = string.len(prefix)

local find = string.find
local sub = string.sub

--- Check if a message has any trigger words
--- @param event EventData.on_console_chat
local function on_console_chat(event)
    if not event.player_index then return end
    local player = assert(game.get_player(event.player_index))
    local message = event.message:lower():gsub("%s+", "")

    -- Check if the player can chat commands
    local commands_allowed = true
    if config.command_admin_only and not player.admin then commands_allowed = false end
    if config.command_permission and not Roles.player_allowed(player, config.command_permission) then commands_allowed = false end

    -- Check if a key word appears in the message
    for key_word, reply in pairs(config.messages) do
        local start_pos = find(message, key_word)
        if start_pos then
            local is_command = sub(message, start_pos - prefix_len - 1, start_pos - 1) == prefix
            if type(reply) == "function" then
                reply = reply(player, is_command)
            end

            if is_command and commands_allowed then
                game.print{ "exp_chat-auto-reply.chat-reply", reply }
            elseif is_command then
                player.print{ "exp_chat-auto-reply.chat-disallowed" }
            elseif not commands_allowed then
                player.print{ "exp_chat-auto-reply.chat-reply", reply }
            end
        end
    end

    if not commands_allowed then return end

    -- Check if a command appears in the message
    for key_word, reply in pairs(config.commands) do
        if find(message, prefix .. key_word) then
            if type(reply) == "function" then
                reply = reply(player, true)
            end
            game.print{ "exp_chat-auto-reply.chat-reply", reply }
        end
    end
end

local e = defines.events

return {
    events = {
        [e.on_console_chat] = on_console_chat,
    }
}
