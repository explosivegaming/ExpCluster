--[[-- Control - Spawn Area
Adds a custom spawn area with chests and afk turrets
]]

local Feature = require("modules/exp_scenario/features")
local feature = require("modules/exp_scenario/config/spawn_area")
local config = feature.config

--- Apply an offset to a LuaPosition
--- @param position MapPosition.struct
--- @param offset MapPosition.struct
--- @return MapPosition.struct
local function apply_offset(position, offset)
    return {
        x = position.x + offset.x,
        y = position.y + offset.y,
    }
end

--- Apply offset to an array of positions
--- @param positions table
--- @param offset MapPosition.struct
--- @param x_index number
--- @param y_index number
local function apply_offset_to_array(positions, offset, x_index, y_index)
    local x = offset.x
    local y = offset.y
    for _, position in ipairs(positions) do
        position[x_index] = position[x_index] + x
        position[y_index] = position[y_index] + y
    end
end

-- Apply the offsets to all config values
apply_offset_to_array(config.turrets.locations, config.turrets.offset, 1, 2)
apply_offset_to_array(config.afk_belts.locations, config.afk_belts.offset, 1, 2)
apply_offset_to_array(config.water.locations, config.water.offset, 1, 2)
apply_offset_to_array(config.pattern.locations, config.pattern.offset, 1, 2)
apply_offset_to_array(config.entities.locations, config.entities.offset, 2, 3)

--- Get or create the force used for entities in spawn
--- @return LuaForce
local function get_spawn_force()
    local force = game.forces["spawn"]
    if force and force.valid then
        return force
    end

    force = game.create_force("spawn")
    force.set_cease_fire("player", true)
    game.forces["player"].set_cease_fire("spawn", true)

    return force
end

--- Protects an entity from player interaction
--- @param entity LuaEntity
local function protect_entity(entity)
    if entity and entity.valid then
        entity.destructible = false
        entity.minable_flag = false
        entity.rotatable = false
        entity.operable = false
    end
end

--- Will spawn all infinite ammo turrets and keep them refilled
local function update_turrets()
    local force = get_spawn_force()
    for _, position in pairs(config.turrets.locations) do
        -- Get or create a valid turret
        local surface = assert(game.get_surface("nauvis"))
        local turret = surface.find_entity("gun-turret", position)
        if not turret or not turret.valid then
            turret = surface.create_entity{ name = "gun-turret", position = position, force = force }
            if not turret then
                goto continue
            end
            protect_entity(turret)
        end

        -- Adds ammo to the turret
        local inv = turret.get_inventory(defines.inventory.turret_ammo)
        if inv and inv.can_insert{ name = config.turrets.ammo_type, count = 10 } then
            inv.insert{ name = config.turrets.ammo_type, count = 10 }
        end

        ::continue::
    end
end

--- Details required to create a 2x2 belt circle
local belt_details = {
    { -0.5, -0.5, defines.direction.east },
    { 0.5, -0.5, defines.direction.south },
    { -0.5, 0.5, defines.direction.north },
    { 0.5, 0.5, defines.direction.west },
}

--- Makes a 2x2 afk belt at the locations in the config
--- @param surface LuaSurface
--- @param offset MapPosition.struct
local function create_belts(surface, offset)
    local belt_type = config.afk_belts.belt_type

    local entity_pos = { x = 0, y = 0 }
    local group_offset = { x = 0, y = 0 }
    for _, position in pairs(config.afk_belts.locations) do
        group_offset.x = position[1] + offset.x
        group_offset.y = position[2] + offset.y
        for _, belt in pairs(belt_details) do
            entity_pos.x = belt[1]
            entity_pos.y = belt[2]
            local pos = apply_offset(entity_pos, group_offset)
            local entity = surface.create_entity{ name = belt_type, position = pos, force = "neutral", direction = belt[3] }
            if entity and config.afk_belts.protected then
                protect_entity(entity)
            end
        end
    end
end

-- Generates extra tiles in a set pattern as defined in the config
--- @param surface LuaSurface
--- @param offset MapPosition.struct
local function create_pattern_tiles(surface, offset)
    local tiles_to_make = {}
    local pattern_tile = config.pattern.pattern_tile

    local tile_pos = { x = 0, y = 0 }
    for index, position in pairs(config.pattern.locations) do
        tile_pos.x = position[1]
        tile_pos.y = position[2]
        tiles_to_make[index] = { name = pattern_tile, position = apply_offset(tile_pos, offset) }
    end

    surface.set_tiles(tiles_to_make)
end

-- Generates extra water as defined in the config
--- @param surface LuaSurface
--- @param offset MapPosition.struct
local function create_water_tiles(surface, offset)
    local tiles_to_make = {}
    local water_tile = config.water.water_tile

    local tile_pos = { x = 0, y = 0 }
    for _, position in pairs(config.water.locations) do
        tile_pos.x = position[1]
        tile_pos.y = position[2]
        table.insert(tiles_to_make, { name = water_tile, position = apply_offset(tile_pos, offset) })
    end

    surface.set_tiles(tiles_to_make)
end

--- Generates the entities that are in the config
--- @param surface LuaSurface
--- @param offset MapPosition.struct
local function create_entities(surface, offset)
    local entity_pos = { x = 0, y = 0 }
    for _, entity_details in pairs(config.entities.locations) do
        entity_pos.x = entity_details[2]
        entity_pos.y = entity_details[3]
        local entity = surface.create_entity{
            name = entity_details[1],
            position = apply_offset(entity_pos, offset),
            force = "neutral"
        }

        if entity then
            if config.entities.protected then
                protect_entity(entity)
            end

            entity.operable = config.entities.operable
        end
    end
end

--- Generates an area with no water or entities, no water area is larger
--- @param surface LuaSurface
--- @param offset MapPosition.struct
local function clear_spawn_area(surface, offset)
    local get_tile = surface.get_tile

    -- Make sure a non water tile is used for filling
    local starting_tile = get_tile(offset.x, offset.y)
    local fill_tile = starting_tile.collides_with("player") and "landfill" or starting_tile.name
    local fill_radius = config.spawn_area.landfill_radius
    local fill_radius_sqr = fill_radius ^ 2

    -- Select the deconstruction tile
    local decon_radius = config.spawn_area.deconstruction_radius
    local decon_tile = config.spawn_area.deconstruction_tile or fill_tile

    local tiles_to_make = {}
    local tile_radius_sqr = config.spawn_area.tile_radius ^ 2
    for x = -fill_radius, fill_radius do -- loop over x
        local x_sqr = (x + 0.5) ^ 2
        for y = -fill_radius, fill_radius do -- loop over y
            local y_sqr = (y + 0.5) ^ 2
            local dst = x_sqr + y_sqr
            local pos = apply_offset({ x = x, y = y }, offset)
            if dst < tile_radius_sqr then
                -- If it is inside the decon radius always set the tile
                tiles_to_make[#tiles_to_make + 1] = { name = decon_tile, position = pos }
            elseif dst < fill_radius_sqr and get_tile(pos.x, pos.y).collides_with("player") then
                -- If it is inside the fill radius only set the tile if it is water
                tiles_to_make[#tiles_to_make + 1] = { name = fill_tile, position = pos }
            end
        end
    end

    -- Remove entities then set the tiles
    local entities_to_remove = surface.find_entities_filtered{ position = offset, radius = decon_radius, name = "character", invert = true }
    for _, entity in pairs(entities_to_remove) do
        entity.destroy()
    end

    surface.set_tiles(tiles_to_make)
end

--- Spawn the resource tiles
--- @param surface LuaSurface
--- @param offset MapPosition.struct
local function create_resources_tiles(surface, offset)
    for _, resource in ipairs(config.resource_tiles.resources) do
        if resource.enabled then
            local pos = apply_offset(resource.offset, offset)
            for x = pos.x, pos.x + resource.size[1] do
                for y = pos.y, pos.y + resource.size[2] do
                    surface.create_entity{ name = resource.name, amount = resource.amount, position = { x = x, y = y } }
                end
            end
        end
    end
end

--- Spawn the resource entities
--- @param surface LuaSurface
--- @param offset MapPosition.struct
local function create_resource_patches(surface, offset)
    for _, resource in ipairs(config.resource_patches.resources) do
        if resource.enabled then
            local pos = apply_offset(resource.offset, offset)
            for i = 1, resource.num_patches do
                surface.create_entity{ name = resource.name, amount = resource.amount, position = { pos.x + resource.offset_next[1] * (i - 1), pos.y + resource.offset_next[2] * (i - 1) } }
            end
        end
    end
end

local on_nth_tick = {}

--- Refill the ammo in the spawn turrets
on_nth_tick[60 * 60 * 5] = function()
    if game.tick < 10 or not config.turrets.enabled then return end
    update_turrets()
end

--- Refill the resources near spawn
on_nth_tick[60 * 60 * 10] = function()
    if game.tick < 10 or not config.resource_refill_nearby.enabled then return end

    local force = game.forces.player
    local surface = assert(game.get_surface("nauvis"))
    local entities = surface.find_entities_filtered{
        position = force.get_spawn_position(surface),
        radius = config.resource_refill_nearby.range,
        name = config.resource_refill_nearby.resources_name
    }

    for _, ore in ipairs(entities) do
        ore.amount = ore.amount + math.random(config.resource_refill_nearby.amount[1], config.resource_refill_nearby.amount[2])
    end
end

--- When the first player joins create the spawn area
--- @param event EventData.on_player_created
local function on_player_created(event)
    if event.player_index ~= 1 then return end
    local player = assert(game.get_player(event.player_index))
    local surface = player.physical_surface
    local offset = { x = 0, y = 0 }
    clear_spawn_area(surface, offset)

    if config.pattern.enabled then create_pattern_tiles(surface, offset) end
    if config.water.enabled then create_water_tiles(surface, offset) end
    if config.afk_belts.enabled then create_belts(surface, offset) end
    if config.entities.enabled then create_entities(surface, offset) end
    if config.resource_tiles.enabled then create_resources_tiles(surface, offset) end
    if config.resource_patches.enabled then create_resource_patches(surface, offset) end
    if config.turrets.enabled then update_turrets() end

    local force = player.force --[[@as LuaForce]]
    force.set_spawn_position(offset, surface)
    player.teleport(offset, surface)
end

local e = defines.events

return feature:guard{
    on_nth_tick = on_nth_tick,
    events = {
        [e.on_player_created] = on_player_created,
    },
}
