--[[-- Control Module - Protection
    - Controls protected entities
    @control Protection
    @alias Protection
]]

local Storage = require("modules/exp_util/storage")
local Event = require("modules/exp_legacy/utils/event") --- @dep utils.event
local config = require("modules.exp_legacy.config.protection") --- @dep config.protection
local EntityProtection = {
    protected_entity_names = table.deep_copy(config.always_protected_names),
    protected_entity_types = table.deep_copy(config.always_protected_types),
    events = {
        --- When a player mines a protected entity
        -- @event on_player_mined_protected
        -- @tparam number player_index the player index of the player who got mined the entity
        -- @tparam LuaEntity entity the entity which was mined
        on_player_mined_protected = script.generate_event_name(),
        --- When a player repeatedly mines protected entities
        -- @event on_repeat_violation
        -- @tparam number player_index the player index of the player who got mined the entities
        -- @tparam LuaEntity entity the last entity which was mined
        on_repeat_violation = script.generate_event_name(),
    },
}

-- Convert config tables into lookup tables
for _, config_key in ipairs{ "always_protected_names", "always_protected_types", "always_trigger_repeat_names", "always_trigger_repeat_types" } do
    local tbl = config[config_key]
    for key, value in ipairs(tbl) do
        tbl[key] = nil
        tbl[value] = true
    end
end

-- Require roles if a permission is assigned in the config
local Roles
if config.ignore_permission then
    Roles = require("modules.exp_legacy.expcore.roles") --- @dep expcore.roles
end

----- Storage Variables -----
--- Variables stored in the global table

local protected_entities = {} -- All entities which are protected
local protected_areas = {} -- All areas which are protected
local repeats = {} -- Stores repeat removals by players

Storage.register({
    protected_entities = protected_entities,
    protected_areas = protected_areas,
    repeats = repeats,
}, function(tbl)
    protected_entities = tbl.protected_entities
    protected_areas = tbl.protected_areas
    repeats = tbl.repeats
end)

----- Local Functions -----
--- Functions used internally to search and add to the protected array

--- Get the key used in protected_entities
local function get_entity_key(entity)
    return string.format("%i,%i", math.floor(entity.position.x), math.floor(entity.position.y))
end

--- Get the key used in protected_areas
local function get_area_key(area)
    return string.format("%i,%i", math.floor(area.left_top.x), math.floor(area.left_top.y))
end

--- Check if an entity is always protected
local function check_always_protected(entity)
    return config.always_protected_names[entity.name] or config.always_protected_types[entity.type] or false
end

--- Check if an entity always triggers repeat protection
local function check_always_trigger_repeat(entity)
    return config.always_trigger_repeat_names[entity.name] or config.always_trigger_repeat_types[entity.type] or false
end

----- Public Functions -----
--- Functions used to add and remove protected entities

--- Add an entity to the protected list
function EntityProtection.add_entity(entity)
    local entities = protected_entities[entity.surface.index]
    if not entities then
        entities = {}
        protected_entities[entity.surface.index] = entities
    end
    entities[get_entity_key(entity)] = entity
end

--- Remove an entity from the protected list
function EntityProtection.remove_entity(entity)
    local entities = protected_entities[entity.surface.index]
    if not entities then return end
    entities[get_entity_key(entity)] = nil
end

--- Get all protected entities on a surface
function EntityProtection.get_entities(surface)
    return protected_entities[surface.index] or {}
end

--- Check if an entity is protected
function EntityProtection.is_entity_protected(entity)
    if check_always_protected(entity) then return true end
    local entities = protected_entities[entity.surface.index]
    if not entities then return false end
    return entities[get_entity_key(entity)] == entity
end

--- Add an area to the protected list
function EntityProtection.add_area(surface, area)
    local areas = protected_areas[surface.index]
    if not areas then
        areas = {}
        protected_areas[surface.index] = areas
    end
    areas[get_area_key(area)] = area
end

--- Remove an area from the protected list
function EntityProtection.remove_area(surface, area)
    local areas = protected_areas[surface.index]
    if not areas then return end
    areas[get_area_key(area)] = nil
end

--- Get all protected areas on a surface
function EntityProtection.get_areas(surface)
    return protected_areas[surface.index] or {}
end

--- Check if an entity is protected
function EntityProtection.is_position_protected(surface, position)
    local areas = protected_areas[surface.index]
    if not areas then return false end
    for _, area in pairs(areas) do
        if area.left_top.x <= position.x and area.left_top.y <= position.y
        and area.right_bottom.x >= position.x and area.right_bottom.y >= position.y
        then
            return true
        end
    end

    return false
end

----- Events -----
--- All events registered by this module

--- Raise events for protected entities
Event.add(defines.events.on_pre_player_mined_item, function(event)
    local entity = event.entity
    local player = game.players[event.player_index]
    -- Check if the player should be ignored
    if config.ignore_admins and player.admin then return end
    if entity.last_user == nil or entity.last_user.index == player.index then return end
    if config.ignore_permission and Roles.player_allowed(player, config.ignore_permission) then return end

    -- Check if the entity is protected
    if EntityProtection.is_entity_protected(entity)
    or EntityProtection.is_position_protected(entity.surface, entity.position)
    then
        -- Update repeats
        local player_repeats = repeats[player.name]
        if not player_repeats then
            player_repeats = { last = game.tick, count = 0 }
            repeats[player.name] = player_repeats
        end
        player_repeats.last = game.tick
        player_repeats.count = player_repeats.count + 1
        -- Send events
        event.name = EntityProtection.events.on_player_mined_protected
        script.raise_event(EntityProtection.events.on_player_mined_protected, event)
        if check_always_trigger_repeat(entity) or player_repeats.count >= config.repeat_count then
            player_repeats.count = 0 -- Reset to avoid spamming of events
            event.name = EntityProtection.events.on_repeat_violation
            script.raise_event(EntityProtection.events.on_repeat_violation, event)
        end
    end
end)

--- Remove old repeats
Event.on_nth_tick(config.refresh_rate, function()
    local old = game.tick - config.repeat_lifetime
    for player_name, player_repeats in pairs(repeats) do
        if player_repeats.last <= old then
            repeats[player_name] = nil
        end
    end
end)

--- When an entity is removed remove it from the protection list
local function event_remove_entity(event)
    EntityProtection.remove_entity(event.entity)
end

Event.add(defines.events.on_space_platform_pre_mined, event_remove_entity)
Event.add(defines.events.on_pre_player_mined_item, event_remove_entity)
Event.add(defines.events.on_robot_pre_mined, event_remove_entity)
Event.add(defines.events.on_entity_died, event_remove_entity)
Event.add(defines.events.script_raised_destroy, event_remove_entity)

return EntityProtection
