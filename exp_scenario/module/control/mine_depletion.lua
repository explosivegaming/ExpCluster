--[[-- Control - Mine Depletion
Marks mining drills for deconstruction when resources deplete
]]

local Async = require("modules/exp_util/async")
local config = require("modules.exp_legacy.config.miner")

local floor = math.floor

--- Orders the deconstruction of an entity by its own force
local order_deconstruction_async =
    Async.register(function(entity)
        --- @cast entity LuaEntity
        entity.order_deconstruction(entity.force)
    end)

--- Reliability get the drop target of an entity
--- @param entity LuaEntity
--- @return LuaEntity?
local function get_drop_chest(entity)
    -- First check the direct drop target
    local target = entity.drop_target
    if target and (target.type == "container" or target.type == "logistic-container" or target.type == "infinity-container") then
        return target
    end

    -- Then check all entities at the drop position
    local entities = entity.surface.find_entities_filtered{
        position = entity.drop_position,
        type = { "container", "logistic-container", "infinity-container" },
    }

    return #entities > 0 and entities[1] or nil
end

--- Check if an entity should has checked performed
--- @param entity LuaEntity
--- @return boolean
local function prevent_deconstruction(entity)
    -- Already waiting to be deconstructed
    if not entity.valid or entity.to_be_deconstructed() then
        return true
    end

    -- Not minable, selectable, or deconstructive
    if not entity.minable or not entity.prototype.selectable_in_game or entity.has_flag("not-deconstructable") then
        return true
    end

    -- Is connected to the circuit network
    local red_write_connection = entity.get_wire_connector(defines.wire_connector_id.circuit_red, false)
    local green_write_connection = entity.get_wire_connector(defines.wire_connector_id.circuit_green, false)
    if red_write_connection and red_write_connection.connection_count > 0
    or green_write_connection and green_write_connection.connection_count > 0 then
        return true
    end

    return false
end

--- Check if an output chest should be deconstructed
--- @param entity LuaEntity
local function try_deconstruct_output_chest(entity)
    -- Get a valid chest as the target
    local target = get_drop_chest(entity)
    if not target or prevent_deconstruction(target) then
        return
    end

    -- Get all adjacent mining drills and inserters
    local entities = target.surface.find_entities_filtered{
        type = { "mining-drill", "inserter" },
        to_be_deconstructed = false,
        area = {
            { target.position.x - 1, target.position.y - 1 },
            { target.position.x + 1, target.position.y + 1 }
        },
    }

    -- Check if any other entity is using this chest
    for _, other in ipairs(entities) do
        if other ~= entity and get_drop_chest(other) == target then
            return
        end
    end

    -- Deconstruct the chest
    order_deconstruction_async:start_after(10, target)
end

--- Check if a miner should be deconstructed
--- @param entity LuaEntity
local function try_deconstruct_miner(entity)
    -- Check if the miner should be deconstructed
    if prevent_deconstruction(entity) then
        return
    end

    -- Check if there are any resources remaining for the miner
    local surface = entity.surface
    local resources = surface.find_entities_filtered{
        type = "resource",
        area = entity.mining_area,
    }

    for _, resource in ipairs(resources) do
        if resource.amount > 0 then
            return
        end
    end

    -- Deconstruct the miner
    order_deconstruction_async:start_after(10, entity)

    -- Try deconstruct the output chest
    if config.chest then
        try_deconstruct_output_chest(entity)
    end

    -- Skip pipe build if not required
    if not config.fluid or #entity.fluidbox == 0 then
        return
    end

    -- Build pipes if the miner used fluid
    local position = entity.position
    local create_entity_position = { x = position.x, y = position.y }
    local create_entity_param = { name = "entity-ghost", inner_name = "pipe", force = entity.force, position = create_entity_position }
    local create_entity = surface.create_entity
    create_entity(create_entity_param)

    -- Find all the entities to connect to
    local bounding_box = entity.bounding_box
    local search_area = {
        { bounding_box.left_top.x - 1, bounding_box.left_top.y - 1 },
        { bounding_box.right_bottom.x + 1, bounding_box.right_bottom.y + 1 },
    }

    local entities = surface.find_entities_filtered{ area = search_area, type = { "mining-drill", "pipe", "pipe-to-ground", "infinity-pipe" } }
    local ghosts = surface.find_entities_filtered{ area = search_area, ghost_type = { "pipe", "pipe-to-ground", "infinity-pipe" } }
    table.insert_array(entities, ghosts)

    -- Check which directions to add pipes in
    local pos_x, pos_y, neg_x, neg_y = false, false, false, false
    for _, other in ipairs(entities) do
        if (other.position.x > position.x) and (other.position.y == position.y) then
            pos_x = true
        elseif (other.position.x < position.x) and (other.position.y == position.y) then
            neg_x = true
        elseif (other.position.x == position.x) and (other.position.y > position.y) then
            pos_y = true
        elseif (other.position.x == position.x) and (other.position.y < position.y) then
            neg_y = true
        end
    end

    -- Build the pipes
    if pos_x then
        create_entity_position.y = floor(position.y)
        for x = position.x + 1, bounding_box.right_bottom.x do
            create_entity_position.x = x
            create_entity(create_entity_param)
        end
    end
    if neg_x then
        create_entity_position.y = floor(position.y)
        for x = floor(bounding_box.left_top.x), floor(position.x - 1) do
            create_entity_position.x = x
            create_entity(create_entity_param)
        end
    end
    if pos_y then
        create_entity_position.x = floor(position.x)
        for y = floor(position.y + 1), floor(bounding_box.right_bottom.y) do
            create_entity_position.y = y
            create_entity(create_entity_param)
        end
    end
    if neg_y then
        create_entity_position.x = floor(position.x)
        for y = floor(bounding_box.left_top.y), floor(position.y - 1) do
            create_entity_position.y = y
            create_entity(create_entity_param)
        end
    end
end

--- Get the max mining radius
local max_mining_radius = 0
for _, proto in pairs(prototypes.get_entity_filtered{ { filter = "type", type = "mining-drill" } }) do
    if proto.mining_drill_radius > max_mining_radius then
        max_mining_radius = proto.mining_drill_radius
    end
end

--- Try deconstruct a miner when its resources deplete
--- @param event EventData.on_resource_depleted
local function on_resource_depleted(event)
    local resource = event.entity
    if resource.prototype.infinite_resource then
        return
    end

    -- Find all mining drills within the area
    local position = resource.position
    local drills = resource.surface.find_entities_filtered{
        type = "mining-drill",
        area = {
            { position.x - max_mining_radius, position.y - max_mining_radius },
            { position.x + max_mining_radius, position.y + max_mining_radius },
        },
    }

    -- Check which could have reached this resource
    for _, drill in pairs(drills) do
        local radius = drill.prototype.mining_drill_radius
        local dx = math.abs(drill.position.x - resource.position.x)
        local dy = math.abs(drill.position.y - resource.position.y)
        if dx <= radius and dy <= radius then
            try_deconstruct_miner(drill)
        end
    end
end

local e = defines.events

return {
    events = {
        [e.on_resource_depleted] = on_resource_depleted,
    },
}
