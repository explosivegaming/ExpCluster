--- Displays the amount of dmg that is done by players to entities;
-- also shows player health when a player is attacked
-- @addon Damage-Popups

local Game = require 'utils.game' --- @dep utils.game
local Event = require 'utils.event' --- @dep utils.event
local config = require 'config.popup_messages' --- @dep config.popup_messages

Event.add(defines.events.on_entity_damaged, function(event)
    local entity = event.entity
    local cause = event.cause
    local damage = math.floor(event.original_damage_amount)
    local health = math.floor(entity.health)
    local health_percentage = entity.get_health_ratio()
    local text_colour = {r=1-health_percentage, g=health_percentage, b=0}

    -- Gets the location of the text
    local size = entity.get_radius()
    if size < 1 then size = 1 end
    local r = (math.random()-0.5)*size*config.damage_location_variance
    local p = entity.position
    local position = {x=p.x+r, y=p.y-size}

    -- Sets the message
    local message
    if entity.name == 'character' and config.show_player_health then
        message = {'damage-popup.player-health', health}
    elseif entity.name ~= 'character' and cause and cause.name == 'character' and config.show_player_damage then
        message = {'damage-popup.player-damage', damage}
    end

    -- Outputs the message as floating text
    if message then
        Game.print_floating_text(
            entity.surface,
            position,
            message,
            text_colour
        )
    end

end)