--- Adds auto replies to chat messages; as well as chat commands
-- @addon Chat-Reply

local Event = require 'utils.event' --- @dep utils.event
local Roles = require 'expcore.roles' --- @dep expcore.roles
local config = require 'config.chat_reply' --- @dep config.chat_reply

Event.add(defines.events.on_console_chat, function(event)
    local player_index = event.player_index
    if not player_index or player_index < 1 then return end
    local player = game.players[player_index]
    local message = event.message:lower():gsub("%s+", "")
    local allowed = true
    if config.command_admin_only and not player.admin then allowed = false end
    if config.command_permission and not Roles.player_allowed(player, config.command_permission) then allowed = false end

    local prefix = config.command_prefix
    for key_word, reply in pairs(config.messages) do
        if message:find(key_word) then
            local is_command = message:find(prefix..key_word)
            if type(reply) == 'function' then
                reply = reply(player, is_command)
            end

            if is_command and allowed then
                game.print{'chat-bot.reply', reply}
            elseif is_command then
                player.print{'chat-bot.disallow'}
            elseif not allowed then
                player.print{'chat-bot.reply', reply}
            end
        end
    end

    if not allowed then return end

    for key_word, reply in pairs(config.commands) do
        if message:find(prefix..key_word) then
            if type(reply) == 'function' then
                local msg = reply(player, true)

                if reply then
                    game.print{'chat-bot.reply', msg}
                end

            else
                game.print{'chat-bot.reply', reply}
            end

        end
    end
end)