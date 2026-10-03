--[[-- Control - Popups
Creates flying text for chat messages and for damage dealt to and by players
]]

local FlyingText = require("modules/exp_util/flying_text")
local Feature = require("modules/exp_scenario/features")

local feature, config = Feature.register("popups", {
    show_player_messages = true, -- weather a message in chat will make a popup above them
    show_player_mentions = true, -- weather a mentioned player will have a popup when mentioned in chat
    show_player_damage = true, -- weather to show damage done by players
    show_player_health = true, -- weather to show player health when attacked
    damage_location_variance = 0.8, -- how close to the eade of an entity the popups will appear
})

local lower = string.lower
local find = string.find
local random = math.random
local floor = math.floor
local max = math.max

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

--- Called when entity entity is damaged including the player character
--- @param event EventData.on_entity_damaged
local function on_entity_damaged(event)
    local message
    local cause = event.cause
    local entity = event.entity

    -- Check which message to display
    if config.show_player_health and entity.name == "character" then
        message = { "exp_damage-popup.flying-text-health", floor(entity.health) }
    elseif config.show_player_damage and entity.name ~= "character" and cause and cause.name == "character" then
        message = { "exp_damage-popup.flying-text-damage", floor(event.original_damage_amount) }
    end

    -- Outputs the message as floating text
    if message then
        local entity_position = entity.position
        local entity_radius = max(1, entity.get_radius())
        local offset = (random() - 0.5) * entity_radius * config.damage_location_variance
        local position = { x = entity_position.x + offset, y = entity_position.y - entity_radius }

        local health_percentage = assert(entity.get_health_ratio())
        local color = { r = 1 - health_percentage, g = health_percentage, b = 0 }

        FlyingText.create{
            text = message,
            position = position,
            color = color,
        }
    end
end

local e = defines.events

return feature:guard{
    events = {
        [e.on_console_chat] = on_console_chat,
        [e.on_entity_damaged] = on_entity_damaged,
    },
}
