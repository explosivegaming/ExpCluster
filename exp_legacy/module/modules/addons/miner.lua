local Event = require 'utils.event_core' --- @dep utils.event_core
local Global = require 'utils.global' --- @dep utils.global
local config = require 'config.miner' --- @dep config.miner

local miner_data = {}

Global.register(miner_data, function(tbl)
    miner_data = tbl
end)

miner_data.queue = {}

local function drop_target(entity)
    if entity.drop_target then
        return entity.drop_target

    else
        local entities = entity.surface.find_entities_filtered{position=entity.drop_position}

        if #entities > 0 then
            return entities[1]
        end
    end
end

local function check_entity(entity)
    if entity.to_be_deconstructed(entity.force) then
        -- if it is already waiting to be deconstruct
        return true
    end

    if next(entity.circuit_connected_entities.red) ~= nil or next(entity.circuit_connected_entities.green) ~= nil then
        -- connected to circuit network
        return true
    end

    if not entity.minable then
        -- if it is minable
        return true
    end

    if not entity.prototype.selectable_in_game then
        -- if it can select
        return true
    end

    if entity.has_flag('not-deconstructable') then
        -- if it can deconstruct
        return true
    end

    return false
end

local function chest_check(entity)
    local target = drop_target(entity)

    if check_entity(entity) then
        return
    end

    if target.type ~= 'logistic-container' and target.type ~= 'container' then
        -- not a chest
        return
    end

    local radius = 2
    local entities = target.surface.find_entities_filtered{area={{target.position.x - radius, target.position.y - radius}, {target.position.x + radius, target.position.y + radius}}, type={'mining-drill', 'inserter'}}

    for _, e in pairs(entities) do
        if drop_target(e) == target then
            if not e.to_be_deconstructed(entity.force) and e ~= entity then
                return
            end
        end
    end

    if check_entity(target) then
        table.insert(miner_data.queue, {t=game.tick + 10, e=target})
    end
end

local function miner_check(entity)
    local ep = entity.position
    local es = entity.surface
    local ef = entity.force
    local er = entity.prototype.mining_drill_radius

    for _, r in pairs(entity.surface.find_entities_filtered{area={{x=ep.x - er, y=ep.y - er}, {x=ep.x + er, y=ep.y + er}}, type='resource'}) do
        if r.amount > 0 then
            return
        end
    end

    --[[
        entity.status ~= defines.entity_status.no_minable_resources
    ]]

    if check_entity(entity) then
        return
    end

    local pipe_build = {}

    if config.fluid and entity.fluidbox and #entity.fluidbox > 0 then
        -- if require fluid to mine
        table.insert(pipe_build, {x=0, y=0})

        local half = math.floor(entity.get_radius())
        local r = 1 + er

        local entities = es.find_entities_filtered{area={{ep.x - r, ep.y - r}, {ep.x + r, ep.y + r}}, type={'mining-drill', 'pipe', 'pipe-to-ground'}}
        local entities_t = es.find_entities_filtered{area={{ep.x - r, ep.y - r}, {ep.x + r, ep.y + r}}, ghost_type={'pipe', 'pipe-to-ground'}}

        table.array_insert(entities, entities_t)

        for _, e in pairs(entities) do
            if (e.position.x > ep.x) and (e.position.y == ep.y) then
                for h=1, half do
                    table.insert(pipe_build, {x=h, y=0})
                end

            elseif (e.position.x < ep.x) and (e.position.y == ep.y) then
                for h=1, half do
                    table.insert(pipe_build, {x=-h, y=0})
                end

            elseif (e.position.x == ep.x) and (e.position.y > ep.y) then
                for h=1, half do
                    table.insert(pipe_build, {x=0, y=h})
                end

            elseif (e.position.x == ep.x) and (e.position.y < ep.y) then
                for h=1, half do
                    table.insert(pipe_build, {x=0, y=-h})
                end
            end
        end
    end

    if config.chest then
        chest_check(entity)
    end

    table.insert(miner_data.queue, {t=game.tick + 5, e=entity})

    for _, pos in ipairs(pipe_build) do
        es.create_entity{name='entity-ghost', position={x=ep.x + pos.x, y=ep.y + pos.y}, force=ef, inner_name='pipe', raise_built=true}
    end
end

Event.add(defines.events.on_resource_depleted, function(event)
    if event.entity.prototype.infinite_resource then
        return
    end

    local entities = event.entity.surface.find_entities_filtered{area={{event.entity.position.x - 1, event.entity.position.y - 1}, {event.entity.position.x + 1, event.entity.position.y + 1}}, type='mining-drill'}

    if #entities == 0 then
        return
    end

    for _, entity in pairs(entities) do
        if ((math.abs(entity.position.x - event.entity.position.x) < entity.prototype.mining_drill_radius) and (math.abs(entity.position.y - event.entity.position.y) < entity.prototype.mining_drill_radius)) then
            miner_check(entity)
        end
    end
end)

Event.on_nth_tick(10, function(event)
    for k, q in pairs(miner_data.queue) do
        if not q.e or not q.e.valid then
            table.remove(miner_data.queue, k)
            break

        elseif event.tick >= q.t then
            q.e.order_deconstruction(q.e.force)
            table.remove(miner_data.queue, k)
        end
    end
end)
