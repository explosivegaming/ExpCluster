--[[-- Control - Protection
Protects entities and areas from being mined by players other than the one who placed them
]]

local Storage = require("modules/exp_util/storage")
local Feature = require("modules/exp_scenario/features")
local Roles = require("modules/exp_roles")

local feature, config = Feature.register("protection", {
    repeat_count = 5, -- Number of protected entities that must be removed within repeat_minutes in order to trigger repeated removal protection
    repeat_minutes = 20, -- The length of time, in minutes, that protected removals will be remembered for
    always_protected_names = Feature.set{}, -- Names of entities which are always protected
    always_protected_types = Feature.set{ -- Types of entities which are always protected
        "boiler", "generator", "offshore-pump", "reactor", "heat-exchanger", "heat-pipe", "fusion-reactor", "fusion-generator", "power-switch", "rocket-silo",
    },
    always_trigger_repeat_names = Feature.set{}, -- Names of entities which always trigger repeated removal protection
    always_trigger_repeat_types = Feature.set{ -- Types of entities which always trigger repeated removal protection
        "reactor", "fusion-reactor", "rocket-silo",
    },
})

local format_string = string.format
local floor = math.floor

--- @class ExpScenario_Protection
local Protection = {
    --- Raised when a player mines a protected entity
    --- @type EventData.ExpScenario_Protection.on_player_mined_protected
    on_player_mined_protected = script.generate_event_name(),
    --- Raised when a player mines protected entities repeatedly, or one which always counts as repeated
    --- @type EventData.ExpScenario_Protection.on_repeat_violation
    on_repeat_violation = script.generate_event_name(),
    --- The config of the feature, read only
    config = config,
    --- @package
    events = {},
    --- @package
    on_nth_tick = {},
}

--- @class EventData.ExpScenario_Protection.on_player_mined_protected : EventData.on_pre_player_mined_item
--- @class EventData.ExpScenario_Protection.on_repeat_violation : EventData.on_pre_player_mined_item

--- @class ExpScenario_Protection.Repeat
--- @field last uint Tick of the last protected removal
--- @field count number Protected removals since the last repeat violation

--- @class ExpScenario_Protection.Registration
--- @field surface_index uint
--- @field key string
--- @field entity LuaEntity

local protected_entities = {} --- @type table<uint, table<string, LuaEntity>> By surface index then entity key
local protected_areas = {} --- @type table<uint, table<string, BoundingBox>> By surface index then area key
local registrations = {} --- @type table<uint64, ExpScenario_Protection.Registration> By on_object_destroyed registration number
local repeats = {} --- @type table<string, ExpScenario_Protection.Repeat> By player name

Storage.register({
    protected_entities = protected_entities,
    protected_areas = protected_areas,
    registrations = registrations,
    repeats = repeats,
}, function(tbl)
    protected_entities = tbl.protected_entities
    protected_areas = tbl.protected_areas
    registrations = tbl.registrations
    repeats = tbl.repeats
end, function(tbl)
    -- Saves from before entities were registered
    tbl.registrations = tbl.registrations or {}
end)

--- Get the key an entity is stored under
--- @param entity LuaEntity
--- @return string
function Protection.get_entity_key(entity)
    return format_string("%i,%i", floor(entity.position.x), floor(entity.position.y))
end

--- Get the key an area is stored under
--- @param area BoundingBox
--- @return string
function Protection.get_area_key(area)
    return format_string("%i,%i", floor(area.left_top.x), floor(area.left_top.y))
end

--- Protect an entity, it is forgotten when destroyed
--- @param entity LuaEntity
function Protection.add_entity(entity)
    local surface_index = entity.surface.index
    local entities = protected_entities[surface_index]
    if not entities then
        entities = {}
        protected_entities[surface_index] = entities
    end
    local key = Protection.get_entity_key(entity)
    entities[key] = entity
    registrations[script.register_on_object_destroyed(entity)] = { surface_index = surface_index, key = key, entity = entity }
end

--- Remove the protection from an entity
--- @param entity LuaEntity
function Protection.remove_entity(entity)
    local entities = protected_entities[entity.surface.index]
    if not entities then return end
    local key = Protection.get_entity_key(entity)
    if entities[key] == entity then
        entities[key] = nil
        registrations[script.register_on_object_destroyed(entity)] = nil
    end
end

--- Get the protected entities on a surface, always protected entities are not included
--- @param surface LuaSurface
--- @return table<string, LuaEntity>
function Protection.get_entities(surface)
    return protected_entities[surface.index] or {}
end

--- Check if an entity is protected, either directly or by its name or type
--- @param entity LuaEntity
--- @return boolean
function Protection.is_entity_protected(entity)
    if config.always_protected_names[entity.name] or config.always_protected_types[entity.type] then return true end
    local entities = protected_entities[entity.surface.index]
    if not entities then return false end
    return entities[Protection.get_entity_key(entity)] == entity
end

--- Protect every position within an area
--- @param surface LuaSurface
--- @param area BoundingBox
function Protection.add_area(surface, area)
    local areas = protected_areas[surface.index]
    if not areas then
        areas = {}
        protected_areas[surface.index] = areas
    end
    areas[Protection.get_area_key(area)] = area
end

--- Remove the protection from an area
--- @param surface LuaSurface
--- @param area BoundingBox
function Protection.remove_area(surface, area)
    local areas = protected_areas[surface.index]
    if not areas then return end
    areas[Protection.get_area_key(area)] = nil
end

--- Get the protected areas on a surface
--- @param surface LuaSurface
--- @return table<string, BoundingBox>
function Protection.get_areas(surface)
    return protected_areas[surface.index] or {}
end

--- Check if a position is within a protected area
--- @param surface LuaSurface
--- @param position MapPosition
--- @return boolean
function Protection.is_position_protected(surface, position)
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

--- Players are never checked against their own entities, and can be excluded by permission
--- @param player LuaPlayer
--- @param entity LuaEntity
--- @return boolean
local function is_ignored(player, entity)
    if entity.last_user == nil or entity.last_user.index == player.index then return true end
    if Roles.player_has_permission(player, "exp_scenario.bypass.entity_protection") then return true end
    return false
end

--- Raise the protection events, the event data is reused with the name replaced
--- @param event EventData.on_pre_player_mined_item
--- @param player LuaPlayer
local function raise_violation(event, player)
    local player_repeats = repeats[player.name]
    if not player_repeats then
        player_repeats = { last = game.tick, count = 0 }
        repeats[player.name] = player_repeats
    end
    player_repeats.last = game.tick
    player_repeats.count = player_repeats.count + 1

    script.raise_event(Protection.on_player_mined_protected, event)

    local entity = event.entity
    local always_repeat = config.always_trigger_repeat_names[entity.name] or config.always_trigger_repeat_types[entity.type]
    if always_repeat or player_repeats.count >= config.repeat_count then
        player_repeats.count = 0
        script.raise_event(Protection.on_repeat_violation, event)
    end
end

--- Raise the protection events when a protected entity is mined
--- @param event EventData.on_pre_player_mined_item
local function on_pre_player_mined_item(event)
    local entity = event.entity
    local player = game.players[event.player_index]
    if
        not is_ignored(player, entity)
        and (Protection.is_entity_protected(entity) or Protection.is_position_protected(entity.surface, entity.position))
    then
        raise_violation(event, player)
    end
end

--- Forget a protected entity once it is destroyed, unless another one took its place
--- @param registration_number uint64
--- @param registration ExpScenario_Protection.Registration
local function forget_entity(registration_number, registration)
    registrations[registration_number] = nil
    local entities = protected_entities[registration.surface_index]
    if entities and entities[registration.key] == registration.entity then
        entities[registration.key] = nil
    end
end

--- @param event EventData.on_object_destroyed
local function on_object_destroyed(event)
    local registration = registrations[event.registration_number]
    if registration then
        forget_entity(event.registration_number, registration)
    end
end

--- Entities destroyed while the feature was disabled were not forgotten
--- @param event EventData.ExpScenario.on_config_updated
local function on_config_updated(event)
    if event.feature_name ~= feature.name or event.path ~= "enabled" then return end
    for registration_number, registration in pairs(registrations) do
        if not registration.entity.valid then
            forget_entity(registration_number, registration)
        end
    end
end

--- Forget protected removals older than the repeat lifetime
local function clear_old_repeats()
    local old = game.tick - config.repeat_minutes * 3600
    for player_name, player_repeats in pairs(repeats) do
        if player_repeats.last <= old then
            repeats[player_name] = nil
        end
    end
end

local e = defines.events

Protection.events[e.on_pre_player_mined_item] = on_pre_player_mined_item
Protection.events[e.on_object_destroyed] = on_object_destroyed
Protection.events[Feature.events.on_config_updated] = on_config_updated
Protection.on_nth_tick[3600 * 5] = clear_old_repeats

return feature:guard(Protection)
