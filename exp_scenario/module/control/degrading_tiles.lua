--[[-- Control - Degrading Tiles
When a player walks around the tiles under them will degrade over time, the same is true when entites are built
]]

local Feature = require("modules/exp_scenario/features")

local feature, config = Feature.register("degrading_tiles", {
    weakness_value = 70, -- lower value will make tiles more likely to degrade
    entities = Feature.set{ -- entities which degrade the tiles under them when they are placed
        "stone-furnace", "steel-furnace", "electric-furnace", "assembling-machine-1", "assembling-machine-2", "assembling-machine-3",
        "beacon", "centrifuge", "chemical-plant", "oil-refinery", "storage-tank", "nuclear-reactor",
        "steam-engine", "steam-turbine", "boiler", "heat-exchanger", "stone-wall", "gate",
        "gun-turret", "laser-turret", "flamethrower-turret", "radar", "lab", "big-electric-pole",
        "substation", "rocket-silo", "pumpjack", "electric-mining-drill", "roboport", "accumulator",
    },
})

local random = math.random

--- How "strong" a tile is, bigger number means less likely to degrade
local strengths = {
    -- debug: /interface require('modules.addons.worn-paths')(player.name,true)
    -- note: tiles are effected by the tiles around them, so player paths will not degrade as fast when made wider
    -- note: values are relative to the tile with the highest value, recommended to keep highest tile as a "nice" number
    -- note: tiles not in list will never degrade under any conditions (which is why some are omitted such as water)
    ["refined-concrete"] = 100,
    ["refined-hazard-concrete-left"] = 100,
    ["refined-hazard-concrete-right"] = 100,
    ["concrete"] = 90,
    ["hazard-concrete-left"] = 90,
    ["hazard-concrete-right"] = 90,
    ["stone-path"] = 80,
    ["red-desert-0"] = 80,
    ["dry-dirt"] = 50,
    -- grass four (main grass tiles)
    ["grass-1"] = 50,
    ["grass-2"] = 40,
    ["grass-3"] = 30,
    ["grass-4"] = 25,
    -- red three (main red tiles)
    ["red-desert-1"] = 40,
    ["red-desert-2"] = 30,
    ["red-desert-3"] = 25,
    -- sand three (main sand tiles)
    ["sand-1"] = 40,
    ["sand-2"] = 30,
    ["sand-3"] = 25,
    -- dirt 3 (main dirt tiles)
    ["dirt-1"] = 40,
    ["dirt-2"] = 30,
    ["dirt-3"] = 25,
    -- last three/four (all sets of three merge here)
    ["dirt-4"] = 25,
    ["dirt-5"] = 30,
    ["dirt-6"] = 40,
    -- ["dirt-7"]=0, -- last tile, nothing to degrade to
    -- land fill chain
    -- ["landfill"]=50,
    -- ["water-shallow"]=90,
    -- ["water-mud"]=0, -- last tile, nothing to degrade to

}

--- When a tile degrades it will turn into the next tile given here
local degrade_order = {
    ["refined-concrete"] = "concrete",
    ["refined-hazard-concrete-left"] = "hazard-concrete-left",
    ["refined-hazard-concrete-right"] = "hazard-concrete-right",
    ["concrete"] = "stone-path",
    ["hazard-concrete-left"] = "stone-path",
    ["hazard-concrete-right"] = "stone-path",
    ["stone-path"] = "dry-dirt",
    ["red-desert-0"] = "dry-dirt",
    ["dry-dirt"] = "dirt-4",
    -- grass four (main grass tiles)
    ["grass-1"] = "grass-2",
    ["grass-2"] = "grass-3",
    ["grass-3"] = "grass-4",
    ["grass-4"] = "dirt-4",
    -- red three (main red tiles)
    ["red-desert-1"] = "red-desert-2",
    ["red-desert-2"] = "red-desert-3",
    ["red-desert-3"] = "dirt-4",
    -- sand three (main sand tiles)
    ["sand-1"] = "sand-2",
    ["sand-2"] = "sand-3",
    ["sand-3"] = "dirt-4",
    -- dirt 3 (main dirt tiles)
    ["dirt-1"] = "dirt-2",
    ["dirt-2"] = "dirt-3",
    ["dirt-3"] = "dirt-4",
    -- last three/four (all sets of three merge here)
    ["dirt-4"] = "dirt-5",
    ["dirt-5"] = "dirt-6",
    ["dirt-6"] = "dirt-7",
    -- ["dirt-7"]=0, -- last tile, nothing to degrade to
    -- land fill chain
    -- ["landfill"]='grass-2', -- 'water-shallow'
    -- ["water-shallow"]='water-mud',
    -- ["water-mud"]=0, -- last tile, nothing to degrade to

}

--- Get the max tile strength
local max_strength = 0
for _, strength in pairs(strengths) do
    if strength > max_strength then
        max_strength = strength
    end
end

--- Replace a tile with the next tile in the degrade chain
--- @param surface LuaSurface
--- @param position MapPosition.struct
local function degrade_tile(surface, position)
    local tile = surface.get_tile(position.x, position.y)
    local tile_name = tile.name
    local degrade_tile_name = degrade_order[tile_name]
    if not degrade_tile_name then return end
    surface.set_tiles{ { name = degrade_tile_name, position = position } }
end

--- Replace all titles under an entity with the next tile in the degrade chain
--- @param entity LuaEntity
local function degrade_entity(entity)
    if not config.entities[entity.name] then return end

    local tiles = {}
    local surface = entity.surface
    local bounding_box = entity.bounding_box
    local left_top = bounding_box.left_top
    local right_bottom = bounding_box.right_bottom
    for x = left_top.x, right_bottom.x do
        for y = left_top.y, right_bottom.y do
            local tile = surface.get_tile(x, y)
            local tile_name = tile.name
            local degrade_tile_name = degrade_order[tile_name]
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
--- @param position MapPosition.struct
--- @return number?
local function get_tile_strength(surface, position)
    local tile = surface.get_tile(position.x, position.y)
    local tile_name = tile.name
    local strength = strengths[tile_name]
    if not strength then return end

    for x = position.x - 1, position.x + 1 do
        for y = position.y - 1, position.y + 1 do
            local check_tile = surface.get_tile(x, y)
            local check_tile_name = check_tile.name
            local check_strength = strengths[check_tile_name] or 0
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

return feature:guard{
    events = {
        [e.on_player_changed_position] = on_player_changed_position,
        [e.on_robot_built_entity] = on_built_entity,
        [e.on_built_entity] = on_built_entity,
    },
}
