--[[-- Control - Chat Popup
Creates flying text entities when a player sends a message in chat
]]

local FlyingText = require("modules/exp_util/flying_text")
local config = require("modules.exp_legacy.config.popup_messages")

local lower = string.lower
local find = string.find

--- Create a chat bubble when a player types a message
--- @param event EventData.on_console_chat
local function on_console_chat(event)
    if not event.player_index then return end
    local player = assert(game.get_player(event.player_index))
    local name = player.name

    -- Sends the message as text above them
    if config.show_player_messages then
        FlyingText.create_as_player{
            target_player = player,
            text = { "exp_chat-popup.flying-text-message", name, event.message },
        }
    end

    if not config.show_player_mentions then return end

    -- Loops over online players to see if they name is included
    local search_string = lower(event.message)
    for _, mentioned_player in ipairs(game.connected_players) do
        if mentioned_player.index ~= player.index then
            if find(search_string, lower(mentioned_player.name), 1, true) then
                FlyingText.create_as_player{
                    target_player = mentioned_player,
                    text = { "exp_chat-popup.flying-text-ping", name },
                }
            end
        end
    end
end

local e = defines.events

return {
    events = {
        [e.on_console_chat] = on_console_chat,
    }
}
