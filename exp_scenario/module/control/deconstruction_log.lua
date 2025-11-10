--[[-- Control - Deconstruction Log
Log certain actions into a file when events are triggered
]]

local ExpUtil = require("modules/exp_util")
local Roles = require("modules.exp_legacy.expcore.roles")
local config = require("modules.exp_legacy.config.deconlog")

local seconds_time_format = ExpUtil.format_time_factory{ format = "short", hours = true, minutes = true, seconds = true }
local format_number = require("util").format_number
local write_file = helpers.write_file
local format_string = string.format
local concat = table.concat

local filepath = "log/deconstruction.log"

--- Clear the log file
local function clear_log()
    helpers.remove_path(filepath)
end

--- Add a new line to the log
--- @param player LuaPlayer
--- @param action string
--- @param ... string
local function add_log_line(player, action, ...)
    local text = concat({
        seconds_time_format(game.tick),
        player.name,
        action,
        ...
    }, ",")

    write_file(filepath, text .. "\n", true, 0)
end

--- Convert a position to a string
--- @param pos MapPosition
--- @return string
local function format_position(pos)
    return format_string("%.1f,%.1f", pos.x, pos.y)
end

--- Convert an area to a string
--- @param area BoundingBox
--- @return string
local function format_area(area)
    return format_string("%.1f,%.1f,%.1f,%.1f", area.left_top.x, area.left_top.y, area.right_bottom.x, area.right_bottom.y)
end

--- Convert an entity to a string
--- @param entity LuaEntity
--- @return string
local function format_entity(entity)
    return format_string("%s,%.1f,%.1f,%s,%s", entity.name, entity.position.x, entity.position.y, entity.direction, entity.orientation)
end

--- Concert a position into a gps tag
--- @param pos MapPosition
--- @param surface_name string
--- @return string
local function format_position_gps(pos, surface_name)
    return format_string("[gps=%.1f,%.1f,%s]", pos.x, pos.y, surface_name)
end

--- Print a message to all players who match the value of admin
--- @param message LocalisedString
local function admin_print(message)
    for _, player in ipairs(game.connected_players) do
        if player.admin then
            player.print(message)
        end
    end
end

--- Check if a log should be created for a player
--- @param event { player_index: number }
--- @return LuaPlayer?
local function get_log_player(event)
    local player = assert(game.get_player(event.player_index))

    if Roles.player_has_flag(player, "deconlog-bypass") then
        return nil
    end

    return player
end

--- Log when an area is deconstructed
--- @param event EventData.on_player_deconstructed_area
local function on_player_deconstructed_area(event)
    local player = get_log_player(event)
    if not player then return end

    --- Don't log when a player clears a deconstruction
    if event.alt then
        return
    end

    local area = event.area
    local surface_name = event.surface.name
    local items = event.surface.find_entities_filtered{ area = area, force = player.force }

    if #items > 250 then
        admin_print{
            "exp_deconstruction-log.chat-admin",
            player.name,
            format_position_gps(area.left_top, surface_name),
            format_position_gps(area.right_bottom, surface_name),
            format_number(#items, false),
        }
    end

    add_log_line(player, "deconstructed_area", surface_name, format_area(area))
end

--- Log when an entity is built
--- @param event EventData.on_built_entity
local function on_built_entity(event)
    local player = get_log_player(event)
    if not player then return end
    add_log_line(player, "built_entity", format_entity(event.entity))
end

--- Log when an entity is mined
--- @param event EventData.on_player_mined_entity
local function on_player_mined_entity(event)
    local player = get_log_player(event)
    if not player then return end
    add_log_line(player, "mined_entity", format_entity(event.entity))
end

--- Log when rocket is fired
--- @param event EventData.on_player_ammo_inventory_changed
local function on_player_ammo_inventory_changed(event)
    local player = get_log_player(event)
    if not player or not player.character then return end

    local character_ammo = assert(player.get_inventory(defines.inventory.character_ammo))
    local item = character_ammo[player.character.selected_gun_index]
    if not item or not item.valid or not item.valid_for_read then
        return
    end

    local action_name = "shot-" .. item.name
    if not config.fired_rocket and action_name == "shot-rocket" then
        return
    elseif not config.fired_explosive_rocket and action_name == "shot-explosive-rocket" then
        return
    elseif not config.fired_nuke and action_name == "shot-atomic-bomb" then
        return
    end

    add_log_line(player, action_name, format_position(player.physical_position), format_position(player.shooting_state.position))
end


local e = defines.events
local events = {
    [e.on_multiplayer_init] = clear_log,
}

if config.decon_area then
    events[e.on_player_deconstructed_area] = on_player_deconstructed_area
end

if config.built_entity then
    events[e.on_built_entity] = on_built_entity
end

if config.mined_entity then
    events[e.on_player_mined_entity] = on_player_mined_entity
end

if config.fired_rocket or config.fired_explosive_rocket or config.fired_nuke then
    events[e.on_player_ammo_inventory_changed] = on_player_ammo_inventory_changed
end

return {
    events = events,
}
