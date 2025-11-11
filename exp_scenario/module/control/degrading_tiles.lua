--[[-- Control - Degrading Tiles
When a player walks around the tiles under them will degrade over time, the same is true when entites are built
]]

local config = require("modules.exp_legacy.config.scorched_earth")

local random = math.random

--- Get the max tile strength
local max_strength = 0
for _, strength in pairs(config.strengths) do
    if strength > max_strength then
        max_strength = strength
    end
end

--- Replace a tile with the next tile in the degrade chain
--- @param surface LuaSurface
--- @param position MapPosition
local function degrade_tile(surface, position)
    --- @diagnostic disable-next-line Incorrect Api Type: https://forums.factorio.com/viewtopic.php?f=233&t=109145&p=593761&hilit=get_tile#p593761
    local tile = surface.get_tile(position)
    local tile_name = tile.name
    local degrade_tile_name = config.degrade_order[tile_name]
    if not degrade_tile_name then return end
    surface.set_tiles{ { name = degrade_tile_name, position = position } }
end

--- Replace all titles under an entity with the next tile in the degrade chain
--- @param entity LuaEntity
local function degrade_entity(entity)
    if not config.entities[entity.name] then return end

    local tiles = {}
    local surface = entity.surface
    local left_top = entity.bounding_box.left_top
    local right_bottom = entity.bounding_box.right_bottom
    for x = left_top.x, right_bottom.x do
        for y = left_top.y, right_bottom.y do
            local tile = surface.get_tile(x, y)
            local tile_name = tile.name
            local degrade_tile_name = config.degrade_order[tile_name]
            if degrade_tile_name then
                tiles[#tiles + 1] = { name = degrade_tile_name, position = { x, y } }
            end
        end
    end

    surface.set_tiles(tiles)
end

--- Covert strength of a tile into a probability to degrade (0 = impossible, 1 = certain)
--- @param strength number
--- @return number
local function get_probability(strength)
    return 1.5 * (1 - (strength / max_strength)) / config.weakness_value
end

--- Gets the average tile strengths around position
--- @param surface LuaSurface
--- @param position MapPosition
--- @return number?
local function get_tile_strength(surface, position)
    --- @diagnostic disable-next-line Incorrect Api Type: https://forums.factorio.com/viewtopic.php?f=233&t=109145&p=593761&hilit=get_tile#p593761
    local tile = surface.get_tile(position)
    local tile_name = tile.name
    local strength = config.strengths[tile_name]
    if not strength then return end

    for x = position.x - 1, position.x + 1 do
        for y = position.y - 1, position.y + 1 do
            local check_tile = surface.get_tile(x, y)
            local check_tile_name = check_tile.name
            local check_strength = config.strengths[check_tile_name] or 0
            strength = strength + check_strength
        end
    end

    return strength / 9
end

--- When the player changes position the tile will have a chance to downgrade
--- @param event EventData.on_player_changed_position
local function on_player_changed_position(event)
    local player = game.players[event.player_index]
    if player.controller_type ~= defines.controllers.character then return end

    local surface = player.physical_surface
    local position = player.physical_position
    local strength = get_tile_strength(surface, position)
    if not strength then return end

    if get_probability(strength) > random() then
        degrade_tile(surface, position)
    end
end

--- When an entity is build there is a much higher chance that the tiles will degrade
--- @param event EventData.on_built_entity | EventData.on_robot_built_entity
local function on_built_entity(event)
    local entity = event.entity
    local strength = get_tile_strength(entity.surface, entity.position)
    if not strength then return end

    if get_probability(strength) * config.weakness_value > random() then
        degrade_entity(entity)
    end
end

local e = defines.events

return {
    events = {
        [e.on_player_changed_position] = on_player_changed_position,
        [e.on_robot_built_entity] = on_built_entity,
        [e.on_built_entity] = on_built_entity,
    },
}
