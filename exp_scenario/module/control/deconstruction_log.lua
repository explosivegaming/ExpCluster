--[[-- Control - Deconstruction Log
Log certain actions into a file when events are triggered
]]

local ExpUtil = require("modules/exp_util")
local Storage = require("modules/exp_util/storage")
local Roles = require("modules/exp_roles")
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
--- @param area BoundingBox.struct
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

    if Roles.player_has_permission(player, "exp_scenario.bypass.deconstruction_log") then
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

--- Ammo which is logged when fired
local logged_ammo = {
    ["rocket"] = config.fired_rocket,
    ["explosive-rocket"] = config.fired_explosive_rocket,
    ["atomic-bomb"] = config.fired_nuke,
}

--- @class ExpScenario_DeconstructionLog.AmmoSlot
--- @field name string
--- @field count number

--- The last seen contents of each ammo slot, keyed by player index then slot index
local ammo_slots = {} --- @type table<uint, table<uint, ExpScenario_DeconstructionLog.AmmoSlot>>
Storage.register(ammo_slots, function(tbl)
    ammo_slots = tbl
end)

--- Log a shot, there is no fired event so a slot losing one of the same ammo is taken as a shot
--- @param event EventData.on_player_ammo_inventory_changed
local function on_player_ammo_inventory_changed(event)
    local player = get_log_player(event)
    if not player or not player.character then return end

    local slots = ammo_slots[player.index]
    if not slots then
        slots = {}
        ammo_slots[player.index] = slots
    end

    local character_ammo = assert(player.get_inventory(defines.inventory.character_ammo))
    for index = 1, #character_ammo do
        local stack = character_ammo[index --[[@as uint]]]
        local previous = slots[index]
        local fired = nil --- @type string?

        if stack.valid_for_read then
            if previous and previous.name == stack.name and previous.count == stack.count + 1 then
                fired = stack.name
            end
            slots[index] = { name = stack.name, count = stack.count }
        else
            if previous and previous.count == 1 then
                fired = previous.name
            end
            slots[index] = nil
        end

        if fired and logged_ammo[fired] then
            add_log_line(player, "shot-" .. fired, format_position(player.physical_position), format_position(player.shooting_state.position))
        end
    end
end

--- Forget the ammo of a player who left, their slots are read again on the next change
--- @param event EventData.on_player_left_game
local function on_player_left_game(event)
    ammo_slots[event.player_index] = nil
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
    events[e.on_player_left_game] = on_player_left_game
end

return {
    events = events,
}
