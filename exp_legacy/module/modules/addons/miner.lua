local Event = require("modules/exp_legacy/utils/event") --- @dep utils.event_core
local Storage = require("modules/exp_util/storage")
local config = require("modules.exp_legacy.config.miner") --- @dep config.miner

local miner_data = {}
Storage.register(miner_data, function(tbl)
    miner_data = tbl
end)

miner_data.queue = {}

local function drop_target(entity)
    if entity.drop_target then
        return entity.drop_target
    else
        local entities = entity.surface.find_entities_filtered{ position = entity.drop_position }

        if #entities > 0 then
            return entities[1]
        else
            return nil
        end
    end
end

local function check_entity(entity)
    if entity.to_be_deconstructed(entity.force) then
        -- if it is already waiting to be deconstruct
        return true
    end

    local egcn = entity.get_wire_connectors()

    if egcn then
        for k, _ in pairs(egcn) do
            if k == defines.wire_connector_id.circuit_red or k == defines.wire_connector_id.circuit_green then
                -- connected to circuit network
                return true
            end
        end
    end

    if not entity.minable then
        -- if it is not minable
        return true
    end

    if not entity.prototype.selectable_in_game then
        -- if it can select
        return true
    end

    if entity.has_flag("not-deconstructable") then
        -- if it can deconstruct
        return true
    end

    return false
end

local function chest_check(entity)
    local target = drop_target(entity)

    if target == nil then
        return
    end

    if check_entity(entity) then
        return
    end

    if target.type ~= "logistic-container" and target.type ~= "container" then
        -- not a chest
        return
    end

    local radius = 2
    local entities = target.surface.find_entities_filtered{ area = { { target.position.x - radius, target.position.y - radius }, { target.position.x + radius, target.position.y + radius } }, type = { "mining-drill", "inserter" } }

    for _, e in pairs(entities) do
        if drop_target(e) == target then
            if not e.to_be_deconstructed(entity.force) and e ~= entity then
                return
            end
        end
    end

    if not check_entity(target) then
        table.insert(miner_data.queue, { t = game.tick + 10, e = target })
    end
end

local function miner_check(entity)
    local ep = entity.position
    local es = entity.surface
    local ef = entity.force
    local er = entity.prototype.mining_drill_radius

    for _, r in pairs(entity.surface.find_entities_filtered{ area = { { x = ep.x - er, y = ep.y - er }, { x = ep.x + er, y = ep.y + er } }, type = "resource" }) do
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
        table.insert(pipe_build, { x = 0, y = 0 })
        local r = er + 1

        local entities = es.find_entities_filtered{ area = { { ep.x - r, ep.y - r }, { ep.x + r, ep.y + r } }, type = { "mining-drill", "pipe", "pipe-to-ground" } }
        local entities_t = es.find_entities_filtered{ area = { { ep.x - r, ep.y - r }, { ep.x + r, ep.y + r } }, ghost_type = { "pipe", "pipe-to-ground" } }

        table.insert_array(entities, entities_t)

        for _, e in pairs(entities) do
            if (e.position.x > ep.x) and (e.position.y == ep.y) then
                for h = 1, er do
                    table.insert(pipe_build, { x = h, y = 0 })
                end
            elseif (e.position.x < ep.x) and (e.position.y == ep.y) then
                for h = 1, er do
                    table.insert(pipe_build, { x = -h, y = 0 })
                end
            elseif (e.position.x == ep.x) and (e.position.y > ep.y) then
                for h = 1, er do
                    table.insert(pipe_build, { x = 0, y = h })
                end
            elseif (e.position.x == ep.x) and (e.position.y < ep.y) then
                for h = 1, er do
                    table.insert(pipe_build, { x = 0, y = -h })
                end
            end
        end
    end

    if config.chest then
        chest_check(entity)
    end

    table.insert(miner_data.queue, { t = game.tick + 5, e = entity })

    for _, pos in ipairs(pipe_build) do
        es.create_entity{ name = "entity-ghost", position = { x = ep.x + pos.x, y = ep.y + pos.y }, force = ef, inner_name = "pipe", raise_built = true }
    end
end

Event.add(defines.events.on_resource_depleted, function(event)
    if event.entity.prototype.infinite_resource then
        return
    end

    local resource = event.entity
    local drills = resource.surface.find_entities_filtered{ type = "mining-drill" }

    for _, entity in pairs(drills) do
        local radius = entity.prototype.mining_drill_radius
        local dx = math.abs(entity.position.x - resource.position.x)
        local dy = math.abs(entity.position.y - resource.position.y)
        if dx <= radius and dy <= radius then
            miner_check(entity)
        end
    end
end)

Event.on_nth_tick(10, function(event)
    for i = #miner_data.queue, 1, -1 do
        local q = miner_data.queue[i]
        if not q.e or not q.e.valid then
            table.remove(miner_data.queue, i)
        elseif event.tick >= q.t then
            q.e.order_deconstruction(q.e.force)
            table.remove(miner_data.queue, i)
        end
    end
end)
