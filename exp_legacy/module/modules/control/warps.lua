--[[-- Control Module - Warps
- Stores warps for each force.
@control Warps
@alias Warps

@usage-- Making a new spawn warp
local player = game.player
local force = player.force
local spawn_id = Warps.add_warp(force.name, player.surface, player.position, player.name, 'Spawn')

Warps.set_spawn_warp(spawn_id, force)
Warps.make_warp_tag(spawn_id)

@usage-- Making a new warp with a warp area
local player = game.player
local force = player.force
local warp_id = Warps.add_warp(force.name, player.surface, player.position, player.name)

Warps.make_warp_area(warp_id)
Warps.make_warp_tag(warp_id)

]]

local Datastore = require 'expcore.datastore' --- @dep expcore.datastore
local Global = require 'utils.global' --- @dep utils.global
local config = require 'config.gui.warps' --- @dep config.warps

--- Stores all data for the warp system
local WrapData = Datastore.connect('WrapData')
WrapData:set_serializer(function(raw_key) return raw_key.warp_id end)

local Warps = {}

-- Global lookup table for force name to task ids
local force_warps = {_uid=1}
---@cast force_warps table<string, { spawn: string, [number]: string }>
Global.register(force_warps, function(tbl)
    force_warps = tbl
end)

-- Create an array of entity names that will be added to the remove filter
local remove_warp_area_entity_names = {}
for _, entity in pairs(config.entities) do
    table.insert(remove_warp_area_entity_names, entity[1])
end

-- When a warp is updated change its chat tag and restore the warp order
WrapData:on_update(function(warp_id, warp, old_warp)
    if warp then
        warp.updates = warp.updates + 1
        -- Update the map chart tag if there is one
        if warp.tag then
            Warps.make_warp_tag(warp_id)
        end

        -- Check that the name of the warp has been changed
        if not old_warp or warp.name == old_warp.name then return end

        -- Get the names of all the warp points for this force
        local force_name = warp.force_name
        local warp_ids = force_warps[force_name]
        local spawn_id = warp_ids.spawn

        local warp_names = {}
        for _, next_warp_id in pairs(warp_ids) do
            local next_warp = WrapData:get(next_warp_id)
            if next_warp_id ~= spawn_id then
                warp_names[next_warp.name..next_warp_id] = next_warp_id
            end
        end

        -- Sort the warp names in alphabetical order
        local new_warp_ids = table.get_values(table.keysort(warp_names))
        table.insert(new_warp_ids, 1,spawn_id)
        new_warp_ids.spawn = spawn_id
        force_warps[force_name] = new_warp_ids
    end
end)

--- Map Integration.
-- functions used to create and alter warps with in the map
-- @section mapIntegration

--[[-- Add or update the chat tag for this warp
@tparam string warp_id the uid of the warp you want the chart tag for
@treturn boolean true if a new tag was made, false if it was updated

@usage-- Adding a chart tag for a new warp
local tag_added = Warps.make_warp_tag(warp_id)

]]
function Warps.make_warp_tag(warp_id)
    local warp = WrapData:get(warp_id)
    local name = warp.name
    local icon = warp.icon

    -- Edit the existing tag if it is present
    local tag = warp.tag

    if tag and tag.valid then
        tag.text = 'Warp: ' .. name
        tag.icon = icon
        return false
    end

    -- Make a new tag if one did not exist
    local force = game.forces[warp.force_name]
    local surface = warp.surface
    local position = warp.position

    tag = force.add_chart_tag(surface, {
        position = {position.x+0.5, position.y+0.5},
        text = 'Warp: ' .. name,
        icon = icon
    })

    -- Add the tag to this warp, store.update not needed as we dont want it to trigger
    warp.tag = tag
    return true
end

--[[-- Remove the chart tag for this warp
@tparam string warp_id the uid for the warp that you want to remove the chart tag from
@treturn boolean true if the tag was valid and was removed, false if the tag was invalid

@usage-- Removing the chart tag from a warp
local removed = Warps.remove_warp_tag(warp_id)

]]
function Warps.remove_warp_tag(warp_id)
    local warp = WrapData:get(warp_id)

    -- Check there is a tag to remove
    local tag = warp.tag
    if not tag or not tag.valid then
        warp.tag = nil
        return false
    end

    -- Remove the warp chart tag if it is valid
    tag.destroy()
    warp.tag = nil

    return true
end

--[[-- Add a warp area for the warp, purely cosmetic
@tparam string warp_id the uid of the warp you want the area for

@usage-- Adding a warp area for a warp
Warps.make_warp_area(warp_id)

]]
function Warps.make_warp_area(warp_id)
    local warp = WrapData:get(warp_id)
    local surface = warp.surface
    local position = warp.position
    local posx = position.x
    local posy = position.y

    -- Get the tile that is being replaced, store.update not needed as we don't want it to trigger
    local old_tile = surface.get_tile(position).name
    warp.old_tile = old_tile

    -- Add a tile pattern on top of the base
    local tiles = {}
    for _, tile in pairs(config.tiles) do
        table.insert(tiles, {name=tile[1], position={tile[2]+posx, tile[3]+posy}})
    end
    surface.set_tiles(tiles)

    -- Add entities to the warp structure
    for _, entity in pairs(config.entities) do
        entity = surface.create_entity{
            name=entity[1],
            position={entity[2]+posx, entity[3]+posy},
            force='neutral'
        }
        entity.destructible = false
        entity.health = 0
        entity.minable = false
        entity.rotatable = false

        -- Save reference of the last power pole
        if entity.type == 'electric-pole' then
            warp.electric_pole = entity
        end
    end
end

--[[-- Remove the warp area for a warp
@tparam string warp_id the uid of the warp that you want to remove the area for

@usage-- Remove the warp area for a warp
Warps.remove_warp_area(warp_id)

]]
function Warps.remove_warp_area(warp_id)
    local warp = WrapData:get(warp_id)
    local position = warp.position
    local surface = warp.surface
    local radius = config.standard_proximity_radius

    -- Check that a warp area was created previously
    local old_tile = warp.old_tile
    if not old_tile then return end

    -- Restore the original tiles before the creation of the warp
    local tiles = {}

    for _, tile in pairs(config.tiles) do
        table.insert(tiles, {name=old_tile, position={tile[2]+position.x, tile[3]+position.y}})
    end

    surface.set_tiles(tiles)

    local area = {
        {position.x-radius, position.y-radius},
        {position.x+radius, position.y+radius}
    }

    -- Remove warp structure entities
    local entities = surface.find_entities_filtered{ force='neutral', area=area, name = remove_warp_area_entity_names }
    for _, entity in pairs(entities) do
        -- Destroy them, this will leave corpses of the entities that it destroyed.
        if entity and entity.valid and entity.destructible == false then
            entity.destructible = true
            entity.die(entity.force)
        end
    end
    -- Rechart map area, useful if warp is not covered by a radar
    game.forces[warp.force_name].chart(surface, area)
end

--[[-- Set a warp to be the spawn point for a force, force must own this warp
@tparam string warp_id the uid of the warp that you want to be the spawn for the force
@tparam LuaForce force the force that you want to set the spawn for

@usage-- Set your forces spawn to a warp
Warps.set_spawn_warp(warp_id, game.player.force)

]]
function Warps.set_spawn_warp(warp_id, force)
    -- Check the force owns this warp
    local warp = WrapData:get(warp_id)
    if warp.force_name ~= force.name then
        return
    end
    -- Set this warp as the spawn
    local warp_ids = force_warps[warp.force_name]
    if not warp_ids then
        warp_ids = {}
        force_warps[warp.force_name] = warp_ids
    end
    warp_ids.spawn = warp_id
    -- Set the forces spawn to this warp
    force.set_spawn_position(warp.position, warp.surface)
end

--[[-- Teleport a player to a warp point
@tparam string warp_id the uid of the warp to send the player to
@tparam LuaPlayer player the player to teleport to the warp

@usage-- Teleport yourself to a warp point
Warps.teleport_player(warp_id, game.player)

]]
function Warps.teleport_player(warp_id, player)
    local warp = WrapData:get(warp_id)
    local surface = warp.surface
    local position = {
        x=warp.position.x+0.5,
        y=warp.position.y+0.5
    }

    if player.vehicle then
        -- Teleport the entity
        local entity = player.vehicle
        local goto_position = surface.find_non_colliding_position(entity.name, position, 32, 1)
        -- Surface teleport can only be done for players and cars at the moment. (with surface as an peramitor it gives this error)
        if entity.type == "car" then
            entity.teleport(goto_position, surface)
        elseif surface.index == entity.surface.index then
            -- Try teleport the entity
            if not entity.teleport(goto_position) then
                player.driving = false
                -- Need to calculate new goto_position because entities have different collision boxes
                goto_position = surface.find_non_colliding_position('character', position, 32, 1)
                player.teleport(goto_position, surface)
            end
        end
    else
        -- Teleport the player
        local goto_position = surface.find_non_colliding_position('character', position, 32, 1)
        if player.driving then player.driving = false end
        player.teleport(goto_position, surface)
    end
end

--- Setters.
-- functions used to created and alter warps
-- @section setters

--[[-- Add a new warp for a force, the warp must have a surface and a position
@tparam string force_name the name of the force to add the warp for
@tparam LuaSurface surface the surface that the warp will be on
@tparam Concepts.Position position the position that the warp will be on
@tparam[opt] string player_name the name of the player that is adding the warp
@tparam[opt] string warp_name the name of the warp that is being added, if omited default is used
@treturn string the uid of the warp which was created

@usage-- Adding a new warp for your force at your position
local player = game.player
local warp_id = Warps.add_warp(player.force.name, player.surface, player.position, player.name)

]]
function Warps.add_warp(force_name, surface, position, player_name, warp_name)
    -- Get new warp id
    local warp_id = tostring(force_warps._uid)
    force_warps._uid = force_warps._uid + 1
    warp_name = warp_name or 'New warp'

    -- Get the existing warps for this force
    local warp_ids = force_warps[force_name]
    if not warp_ids then
        warp_ids = {}
        force_warps[force_name] = warp_ids
    end

    -- Insert the warp id into the force warps
    table.insert(warp_ids, warp_id)

    -- Create the editing table
    local editing = {}
    if player_name then
        editing[player_name] = true
    end

    -- Add the new warp to the store
    WrapData:set(warp_id, {
        warp_id = warp_id,
        force_name = force_name,
        name = warp_name,
        icon = { type = config.default_icon.type, name = config.default_icon.name },
        surface = surface,
        position = {
            x = math.floor(position.x),
            y = math.floor(position.y)
        },
        last_edit_name = player_name or '<server>',
        last_edit_time = game.tick,
        currently_editing = editing,
        updates = 0,
    })

    return warp_id
end

--[[-- Removes a warp and any data linked to it
@tparam string warp_id the uid of the warp that you want to remove

@usage-- Removing a warp
Warps.remove_warp(warp_id)

]]
function Warps.remove_warp(warp_id)
    local warp = WrapData:get(warp_id)
    local force_name = warp.force_name
    Warps.remove_warp_tag(warp_id)
    Warps.remove_warp_area(warp_id)
    WrapData:remove(warp_id)
    table.remove_element(force_warps[force_name], warp_id)
end

--[[-- Update the name and icon for a warp
@tparam string warp_id the uid of the warp that you want to update
@tparam[opt] string new_name the new name that you want the warp to have
@tparam[opt] string new_icon the new icon that you want the warp to have
@tparam[opt='server'] string player_name the name of the player that made the edit

@usage-- Changing the name and icon for a warp
Warps.update_warp(warp_id, 'My Warp', 'iron-plate', game.player.name)

]]
function Warps.update_warp(warp_id, new_name, new_icon, player_name)
    WrapData:update(warp_id, function(_, warp)
        -- If the icon is not valid then replace with the old icon
        if new_icon and not new_icon.name or not new_icon.type then
            new_icon = warp.icon
        end

        warp.last_edit_name = player_name or '<server>'
        warp.last_edit_time = game.tick
        warp.name = new_name or warp.name
        warp.icon = new_icon or warp.icon
    end)
end

--[[-- Set the editing state for a player, can be used as a warning or to display a text field
@tparam string warp_id the uid of the warp that you want to effect
@tparam string player_name the name of the player you want to set the state for
@tparam boolean state the new state to set editing to

@usage-- Setting your editing state to true
Warps.set_editing(warp_id, game.player.name, true)

]]
function Warps.set_editing(warp_id, player_name, state)
    WrapData:update(warp_id, function(_, warp)
        warp.currently_editing[player_name] = state
    end)
end

--[[-- Adds an update handler for when a warp is added, removed, or updated
@tparam function handler the handler which is called when a warp is updated

@usage-- Add a game print when a warp is updated
Warps.on_update(function(warp)
    game.print(warp.force_name..' now has the warp: '..warp.name)
end)

]]
function Warps.on_update(handler)
    WrapData:on_update(handler)
end

--- Getters.
-- function used to get information about warps
-- @section getters

--[[-- Gets the warp information that is linked with this id
@tparam string warp_id the uid of the warp you want to get
@treturn table the warp information

@usage-- Getting warp information outside of on_update
local warp = Warps.get_warp(warp_id)

]]
function Warps.get_warp(warp_id)
    return WrapData:get(warp_id)
end

--[[-- Gets all the warp ids that a force has
@tparam string force_name the name of the force that you want the warp ids for
@treturn table an array of all the warp ids

@usage-- Getting the warp ids for a force
local warp_ids = Warps.get_force_warp_ids(game.player.force.name)

]]
function Warps.get_force_warp_ids(force_name)
    return force_warps[force_name] or {}
end

--[[-- Get the id of the spawn warp
@tparam string force_name the name of the force that you want to get the spawn warp for
@treturn ?string|nil the uid of the spawn warp for this force if there is one

@usage-- Getting the spawn warp id
local spawn_id = Warps.get_spawn_warp_id(game.player.force.name)

]]
function Warps.get_spawn_warp_id(force_name)
    local warp_ids = force_warps[force_name] or {}
    return warp_ids.spawn
end

--[[-- Gets the editing state for a player
@tparam string warp_id the uid of the warp you want to check
@tparam string player_name the name of the player that you want to check
@treturn boolean weather the player is currently editing this warp

@usage-- Check if a player is editing a warp or not
local editing = Warps.get_editing(warp_id, game.player.name)

]]
function Warps.get_editing(warp_id, player_name)
    local warp = WrapData:get(warp_id)
    return warp.currently_editing[player_name]
end

-- Module return
return Warps
