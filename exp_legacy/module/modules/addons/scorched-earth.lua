--- When a player walks around the tiles under them will degrade over time, the same is true when entites are built
-- @addon Scorched-Earth

local Event = require("modules/exp_legacy/utils/event") --- @dep utils.event
local config = require("modules.exp_legacy.config.scorched_earth") --- @dep config.scorched_earth

-- Loops over the config and finds the wile which has the highest value for strength
local max_strength = 0
for _, strength in pairs(config.strengths) do
    if strength > max_strength then
        max_strength = strength
    end
end

-- Will degrade a tile down to the next tile when called
local function degrade(surface, position)
    --- @diagnostic disable-next-line Incorrect Api Type: https://forums.factorio.com/viewtopic.php?f=233&t=109145&p=593761&hilit=get_tile#p593761
    local tile = surface.get_tile(position)
    local tile_name = tile.name
    local degrade_tile_name = config.degrade_order[tile_name]
    if not degrade_tile_name then return end
    surface.set_tiles{ { name = degrade_tile_name, position = position } }
end

-- Same as degrade but will degrade all tiles that are under an entity
local function degrade_entity(entity)
    local surface = entity.surface
    local position = entity.position
    local tiles = {}
    if not config.entities[entity.name] then return end
    local box = entity.prototype.collision_box
    local lt = box.left_top
    local rb = box.right_bottom
    for x = lt.x, rb.x do -- x loop
        local px = position.x + x
        for y = lt.y, rb.y do -- y loop
            local p = { x = px, y = position.y + y }
            local tile = surface.get_tile(p)
            local tile_name = tile.name
            local degrade_tile_name = config.degrade_order[tile_name]
            if not degrade_tile_name then return end
            table.insert(tiles, { name = degrade_tile_name, position = p })
        end
    end

    surface.set_tiles(tiles)
end

-- Turns the strength of a tile into a probability (0 = impossible, 1 = certain)
local function get_probability(strength)
    local v1 = strength / max_strength
    local dif = 1 - v1
    local v2 = dif / 2
    return (1 - v1 + v2) / config.weakness_value
end

-- Gets the mean of the strengths around a tile to give the strength at that position
local function get_tile_strength(surface, position)
    --- @diagnostic disable-next-line Incorrect Api Type: https://forums.factorio.com/viewtopic.php?f=233&t=109145&p=593761&hilit=get_tile#p593761
    local tile = surface.get_tile(position)
    local tile_name = tile.name
    local strength = config.strengths[tile_name]
    if not strength then return end
    for x = -1, 1 do -- x loop
        local px = position.x + x
        for y = -1, 1 do -- y loop
            local check_tile = surface.get_tile(px, position.y + y)
            local check_tile_name = check_tile.name
            local check_strength = config.strengths[check_tile_name] or 0
            strength = strength + check_strength
        end
    end

    return strength / 9
end

-- When the player changes position the tile will have a chance to downgrade, debug check is here
Event.add(defines.events.on_player_changed_position, function(event)
    local player = game.players[event.player_index]
    if player.controller_type ~= defines.controllers.character then return end
    local surface = player.physical_surface
    local position = player.physical_position
    local strength = get_tile_strength(surface, position)
    if not strength then return end
    if get_probability(strength) > math.random() then
        degrade(surface, position)
    end
end)

-- When an entity is build there is a much higher chance that the tiles will degrade
local function on_built_entity(event)
    local entity = event.entity
    local strength = get_tile_strength(entity.surface, entity.position)
    if not strength then return end
    if get_probability(strength) * config.weakness_value > math.random() then
        degrade_entity(entity)
    end
end

Event.add(defines.events.on_built_entity, on_built_entity)
Event.add(defines.events.on_robot_built_entity, on_built_entity)
