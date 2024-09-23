--[[-- Commands Module - Protection
    - Adds commands that can add and remove protection
    @commands Protection
]]

local Event = require 'utils.event' --- @dep utils.event
local Global = require 'utils.global' --- @dep utils.global
local Roles = require 'expcore.roles' --- @dep expcore.roles
local Commands = require 'expcore.commands' --- @dep expcore.commands
local format_chat_player_name = _C.format_chat_player_name --- @dep expcore.common
local EntityProtection = require 'modules.control.protection' --- @dep modules.control.protection
local Selection = require 'modules.control.selection' --- @dep modules.control.selection

local SelectionProtectEntity = 'ProtectEntity'
local SelectionProtectArea   = 'ProtectArea'

local renders = {} -- Stores all renders for a player
Global.register({
    renders = renders
}, function(tbl)
    renders = tbl.renders
end)

--- Test if a point is inside an aabb
local function aabb_point_enclosed(point, aabb)
    return point.x >= aabb.left_top.x and point.y >= aabb.left_top.y
        and point.x <= aabb.right_bottom.x and point.y <= aabb.right_bottom.y
end

--- Test if an aabb is inside another aabb
local function aabb_area_enclosed(aabbOne, aabbTwo)
    return aabb_point_enclosed(aabbOne.left_top, aabbTwo)
        and aabb_point_enclosed(aabbOne.right_bottom, aabbTwo)
end

--- Align an aabb to the grid by expanding it
local function aabb_align_expand(aabb)
    return {
        left_top = {x = math.floor(aabb.left_top.x), y = math.floor(aabb.left_top.y)},
        right_bottom = {x = math.ceil(aabb.right_bottom.x), y = math.ceil(aabb.right_bottom.y)}
    }
end

--- Get the key used in protected_entities
local function get_entity_key(entity)
    return string.format('%i,%i', math.floor(entity.position.x), math.floor(entity.position.y))
end

--- Get the key used in protected_areas
local function get_area_key(area)
    return string.format('%i,%i', math.floor(area.left_top.x), math.floor(area.left_top.y))
end

--- Show a protected entity to a player
local function show_protected_entity(player, entity)
    local key = get_entity_key(entity)
    if renders[player.index][key] then return end
    local rb = entity.selection_box.right_bottom
    local render_id = rendering.draw_sprite{
        sprite = 'utility/notification',
        target = entity,
        target_offset = {
            (rb.x-entity.position.x)*0.75,
            (rb.y-entity.position.y)*0.75
        },
        x_scale = 2,
        y_scale = 2,
        surface = entity.surface,
        players = { player }
    }
    renders[player.index][key] = render_id
end

--- Show a protected area to a player
local function show_protected_area(player, surface, area)
    local key = get_area_key(area)
    if renders[player.index][key] then return end
    local render_id = rendering.draw_rectangle{
        color = {1, 1, 0, 0.5},
        filled = false,
        width = 3,
        left_top = area.left_top,
        right_bottom = area.right_bottom,
        surface = surface,
        players = { player }
    }
    renders[player.index][key] = render_id
end

--- Remove a render object for a player
local function remove_render(player, key)
    local render = renders[player.index][key]
    if render and rendering.is_valid(render) then rendering.destroy(render) end
    renders[player.index][key] = nil
end

--- Toggles entity protection selection
-- @command protect-entity
Commands.new_command('protect-entity', {'expcom-protection.description-pe'}, 'Toggles entity protection selection, hold shift to remove protection')
:add_alias('pe')
:register(function(player)
    if Selection.is_selecting(player, SelectionProtectEntity) then
        Selection.stop(player)
    else
        Selection.start(player, SelectionProtectEntity)
        return Commands.success{'expcom-protection.entered-entity-selection'}
    end
end)

--- Toggles area protection selection
-- @command protect-area
Commands.new_command('protect-area', {'expcom-protection.description-pa'}, 'Toggles area protection selection, hold shift to remove protection')
:add_alias('pa')
:register(function(player)
    if Selection.is_selecting(player, SelectionProtectArea) then
        Selection.stop(player)
    else
        Selection.start(player, SelectionProtectArea)
        return Commands.success{'expcom-protection.entered-area-selection'}
    end
end)

--- When an area is selected to add protection to entities
Selection.on_selection(SelectionProtectEntity, function(event)
    local player = game.get_player(event.player_index)
    for _, entity in ipairs(event.entities) do
        EntityProtection.add_entity(entity)
        show_protected_entity(player, entity)
    end
    player.print{'expcom-protection.protected-entities', #event.entities}
end)

--- When an area is selected to remove protection from entities
Selection.on_alt_selection(SelectionProtectEntity, function(event)
    local player = game.get_player(event.player_index)
    for _, entity in ipairs(event.entities) do
        EntityProtection.remove_entity(entity)
        remove_render(player, get_entity_key(entity))
    end
    player.print{'expcom-protection.unprotected-entities', #event.entities}
end)

--- When an area is selected to add protection to the area
Selection.on_selection(SelectionProtectArea, function(event)
    local area = aabb_align_expand(event.area)
    local areas = EntityProtection.get_areas(event.surface)
    local player = game.get_player(event.player_index)
    for _, next_area in pairs(areas) do
        if aabb_area_enclosed(area, next_area) then
            return player.print{'expcom-protection.already-protected'}
        end
    end
    EntityProtection.add_area(event.surface, area)
    show_protected_area(player, event.surface, area)
    player.print{'expcom-protection.protected-area'}
end)

--- When an area is selected to remove protection from the area
Selection.on_alt_selection(SelectionProtectArea, function(event)
    local area = aabb_align_expand(event.area)
    local areas = EntityProtection.get_areas(event.surface)
    local player = game.get_player(event.player_index)
    for _, next_area in pairs(areas) do
        if aabb_area_enclosed(next_area, area) then
            EntityProtection.remove_area(event.surface, next_area)
            player.print{'expcom-protection.unprotected-area'}
            remove_render(player, get_area_key(next_area))
        end
    end
end)

--- When selection starts show all protected entities and protected areas
Event.add(Selection.events.on_player_selection_start, function(event)
    if event.selection ~= SelectionProtectEntity and event.selection ~= SelectionProtectArea then return end
    local player = game.get_player(event.player_index)
    local surface = player.surface
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
end)

--- When selection ends hide protected entities and protected areas
Event.add(Selection.events.on_player_selection_end, function(event)
    if event.selection ~= SelectionProtectEntity and event.selection ~= SelectionProtectArea then return end
    for _, id in pairs(renders[event.player_index]) do
        if rendering.is_valid(id) then rendering.destroy(id) end
    end
    renders[event.player_index] = nil
end)

--- When there is a repeat offence print it in chat
Event.add(EntityProtection.events.on_repeat_violation, function(event)
    local player_name = format_chat_player_name(event.player_index)
    Roles.print_to_roles_higher('Regular', {'expcom-protection.repeat-offence', player_name, event.entity.localised_name, event.entity.position.x, event.entity.position.y})
end)
