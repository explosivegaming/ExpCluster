--[[-- Control - Protection
Protects entities and areas from being mined by players other than the one who placed them
]]

local Storage = require("modules/exp_util/storage")
local Roles = require("modules/exp_roles")
local config = require("modules.exp_legacy.config.protection")

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
    --- Names of entities which are always protected
    --- @type string[]
    protected_entity_names = config.always_protected_names,
    --- Types of entities which are always protected
    --- @type string[]
    protected_entity_types = config.always_protected_types,
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

--- @param values string[]
--- @return table<string, true>
local function to_set(values)
    local set = {}
    for _, value in ipairs(values) do
        set[value] = true
    end
    return set
end

local always_protected_names = to_set(config.always_protected_names)
local always_protected_types = to_set(config.always_protected_types)
local always_trigger_repeat_names = to_set(config.always_trigger_repeat_names)
local always_trigger_repeat_types = to_set(config.always_trigger_repeat_types)

local protected_entities = {} --- @type table<uint, table<string, LuaEntity>> Keyed by surface index then entity key
local protected_areas = {} --- @type table<uint, table<string, BoundingBox>> Keyed by surface index then area key
local repeats = {} --- @type table<string, ExpScenario_Protection.Repeat> Keyed by player name

Storage.register({
    protected_entities = protected_entities,
    protected_areas = protected_areas,
    repeats = repeats,
}, function(tbl)
    protected_entities = tbl.protected_entities
    protected_areas = tbl.protected_areas
    repeats = tbl.repeats
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

--- Protect an entity
--- @param entity LuaEntity
function Protection.add_entity(entity)
    local entities = protected_entities[entity.surface.index]
    if not entities then
        entities = {}
        protected_entities[entity.surface.index] = entities
    end
    entities[Protection.get_entity_key(entity)] = entity
end

--- Remove the protection from an entity
--- @param entity LuaEntity
function Protection.remove_entity(entity)
    local entities = protected_entities[entity.surface.index]
    if not entities then return end
    entities[Protection.get_entity_key(entity)] = nil
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
    if always_protected_names[entity.name] or always_protected_types[entity.type] then return true end
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

--- Players are never checked against their own entities, and can be excluded by permission or admin status
--- @param player LuaPlayer
--- @param entity LuaEntity
--- @return boolean
local function is_ignored(player, entity)
    if config.ignore_admins and player.admin then return true end
    if entity.last_user == nil or entity.last_user.index == player.index then return true end
    if config.ignore_permission and Roles.player_has_permission(player, config.ignore_permission) then return true end
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

    event.name = Protection.on_player_mined_protected
    script.raise_event(Protection.on_player_mined_protected, event)

    local entity = event.entity
    local always_repeat = always_trigger_repeat_names[entity.name] or always_trigger_repeat_types[entity.type]
    if always_repeat or player_repeats.count >= config.repeat_count then
        player_repeats.count = 0
        event.name = Protection.on_repeat_violation
        script.raise_event(Protection.on_repeat_violation, event)
    end
end

--- Raise the protection events when a protected entity is mined, then forget the entity
--- @param event EventData.on_pre_player_mined_item
local function on_pre_player_mined_item(event)
    local entity = event.entity
    local player = game.players[event.player_index]
    if not is_ignored(player, entity)
    and (Protection.is_entity_protected(entity) or Protection.is_position_protected(entity.surface, entity.position))
    then
        raise_violation(event, player)
    end

    Protection.remove_entity(entity)
end

--- Forget an entity once it no longer exists
--- @param event { entity: LuaEntity }
local function on_entity_removed(event)
    Protection.remove_entity(event.entity)
end

--- Forget protected removals older than the repeat lifetime
local function clear_old_repeats()
    local old = game.tick - config.repeat_lifetime
    for player_name, player_repeats in pairs(repeats) do
        if player_repeats.last <= old then
            repeats[player_name] = nil
        end
    end
end

local e = defines.events

Protection.events[e.on_pre_player_mined_item] = on_pre_player_mined_item
Protection.events[e.on_space_platform_pre_mined] = on_entity_removed
Protection.events[e.on_robot_pre_mined] = on_entity_removed
Protection.events[e.on_entity_died] = on_entity_removed
Protection.events[e.script_raised_destroy] = on_entity_removed
Protection.on_nth_tick[config.refresh_rate] = clear_old_repeats

return Protection
