--[[-- Control - Damage PopUps
Displays the amount of dmg that is done by players to entities;
also shows player health when a player is attacked
]]

local FlyingText = require("modules/exp_util/flying_text")
local Features = require("modules/exp_scenario/features")
local config = require("modules/exp_scenario/config/popups")

local random = math.random
local floor = math.floor
local max = math.max

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

return Features.guard(config, {
    events = {
        [e.on_entity_damaged] = on_entity_damaged,
    },
})
