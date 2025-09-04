--[[-- Commands - Protection
Adds commands that can add and remove protection
]]

local Storage = require("modules/exp_util/storage")

local AABB = require("modules/exp_util/aabb")
local contains_area = AABB.contains_area
local expand_area = AABB.expand

local Commands = require("modules/exp_commands")
local format_player_name = Commands.format_player_name_locale

local Roles = require("modules.exp_legacy.expcore.roles") --- @dep expcore.roles
local EntityProtection = require("modules.exp_legacy.modules.control.protection") --- @dep modules.control.protection

local format_string = string.format
local floor = math.floor

local Selection = require("modules/exp_util/selection")
local SelectEntities = Selection.connect("ExpCommand_ProtectEntity")
local SelectArea = Selection.connect("ExpCommand_ProtectArea")

local renders = {} --- @type table<number, table<string, LuaRenderObject>> Stores all renders for a player
Storage.register({
    renders = renders,
}, function(tbl)
    renders = tbl.renders
end)

--- Get the key used in protected_entities
--- @param entity LuaEntity
--- @return string
local function get_entity_key(entity)
    return format_string("%i,%i", floor(entity.position.x), floor(entity.position.y))
end

--- Get the key used in protected_areas
--- TODO expose this from EntityProtection
--- @param area BoundingBox
--- @return string
local function get_area_key(area)
    return format_string("%i,%i", floor(area.left_top.x), floor(area.left_top.y))
end

--- Show a protected entity to a player
--- @param player LuaPlayer
--- @param entity LuaEntity
local function show_protected_entity(player, entity)
    local key = get_entity_key(entity)
    if renders[player.index][key] then return end
    local rb = entity.selection_box.right_bottom
    renders[player.index][key] = rendering.draw_sprite{
        sprite = "utility/notification",
        target = entity,
        target_offset = {
            (rb.x - entity.position.x) * 0.75,
            (rb.y - entity.position.y) * 0.75,
        },
        x_scale = 2,
        y_scale = 2,
        surface = entity.surface,
        players = { player },
    }
end

--- Show a protected area to a player
--- @param player LuaPlayer
--- @param surface LuaSurface
--- @param area BoundingBox
local function show_protected_area(player, surface, area)
    local key = get_area_key(area)
    if renders[player.index][key] then return end
    renders[player.index][key] = rendering.draw_rectangle{
        color = { 1, 1, 0, 0.5 },
        filled = false,
        width = 3,
        left_top = area.left_top,
        right_bottom = area.right_bottom,
        surface = surface,
        players = { player },
    }
end

--- Remove a render object for a player
--- @param player LuaPlayer
--- @param key string
local function remove_render(player, key)
    local render = renders[player.index][key]
    if render and render.valid then render.destroy() end
    renders[player.index][key] = nil
end

--- Toggles entity protection selection
Commands.new("protect-entity", { "exp-commands_entity-protection.description-entity" })
    :add_aliases{ "pe" }
    :register(function(player)
        if SelectEntities:stop(player) then
            return Commands.status.success{ "exp-commands_entity-protection.exit-entity" }
        end
        SelectEntities:start(player)
        return Commands.status.success{ "exp-commands_entity-protection.enter-entity" }
    end)

--- Toggles area protection selection
Commands.new("protect-area", { "exp-commands_entity-protection.description-area" })
    :add_aliases{ "pa" }
    :register(function(player)
        if SelectArea:stop(player) then
            return Commands.status.success{ "exp-commands_entity-protection.exit-area" }
        end
        SelectArea:start(player)
        return Commands.status.success{ "exp-commands_entity-protection.enter-area" }
    end)

--- When an area is selected to add protection to entities
SelectEntities:on_selection(function(event)
    local player = game.players[event.player_index]
    for _, entity in ipairs(event.entities) do
        EntityProtection.add_entity(entity)
        show_protected_entity(player, entity)
    end

    player.print({ "exp-commands_entity-protection.protected-entities", #event.entities }, Commands.print_settings.default)
end)

--- When an area is selected to remove protection from entities
SelectEntities:on_alt_selection(function(event)
    local player = game.players[event.player_index]
    for _, entity in ipairs(event.entities) do
        EntityProtection.remove_entity(entity)
        remove_render(player, get_entity_key(entity))
    end

    player.print({ "exp-commands_entity-protection.unprotected-entities", #event.entities }, Commands.print_settings.default)
end)

--- When an area is selected to add protection to the area
SelectArea:on_selection(function(event)
    local surface = event.surface
    local area = expand_area(event.area)
    local areas = EntityProtection.get_areas(event.surface)
    local player = game.players[event.player_index]
    for _, next_area in pairs(areas) do
        if contains_area(next_area, area) then
            return player.print({ "exp-commands_entity-protection.already-protected" }, Commands.print_settings.error)
        end
    end

    EntityProtection.add_area(surface, area)
    show_protected_area(player, surface, area)
    player.print({ "exp-commands_entity-protection.protected-area" }, Commands.print_settings.default)
end)

--- When an area is selected to remove protection from the area
SelectArea:on_alt_selection(function(event)
    local surface = event.surface
    local area = expand_area(event.area)
    local areas = EntityProtection.get_areas(surface)
    local player = game.players[event.player_index]
    for _, next_area in pairs(areas) do
        if contains_area(area, next_area) then
            EntityProtection.remove_area(surface, next_area)
            player.print({ "exp-commands_entity-protection.unprotected-area" }, Commands.print_settings.default)
            remove_render(player, get_area_key(next_area))
        end
    end
end)

--- When selection starts show all protected entities and protected areas
local function on_player_selection_start(event)
    local player = game.players[event.player_index]
    local surface = player.surface -- Allow remote view
    renders[player.index] = {}

    -- Show protected entities
    local entities = EntityProtection.get_entities(surface)
    for _, entity in pairs(entities) do
        show_protected_entity(player, entity)
    end

    -- Show always protected entities by name
    if #EntityProtection.protected_entity_names > 0 then
        for _, entity in pairs(surface.find_entities_filtered{ name = EntityProtection.protected_entity_names, force = player.force }) do
            show_protected_entity(player, entity)
        end
    end

    -- Show always protected entities by type
    if #EntityProtection.protected_entity_types > 0 then
        for _, entity in pairs(surface.find_entities_filtered{ type = EntityProtection.protected_entity_types, force = player.force }) do
            show_protected_entity(player, entity)
        end
    end

    -- Show protected areas
    local areas = EntityProtection.get_areas(surface)
    for _, area in pairs(areas) do
        show_protected_area(player, surface, area)
    end
end

--- When selection ends hide protected entities and protected areas
local function on_player_selection_stop(event)
    for _, render in pairs(renders[event.player_index]) do
        if render.valid then render.destroy() end
    end

    renders[event.player_index] = nil
end

SelectArea:on_start(on_player_selection_start)
SelectEntities:on_start(on_player_selection_start)
SelectArea:on_stop(on_player_selection_stop)
SelectEntities:on_stop(on_player_selection_stop)

--- When there is a repeat offence print it in chat
local function on_repeat_violation(event)
    Roles.print_to_roles_higher("Regular", {
        "exp-commands_entity-protection.repeat-offence",
        format_player_name(event.player_index),
        event.entity.localised_name,
        event.entity.position.x,
        event.entity.position.y
    })
end

return {
    events = {
        [EntityProtection.events.on_repeat_violation] = on_repeat_violation,
    }
}
