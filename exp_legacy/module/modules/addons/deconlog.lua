--- Log certain actions into a file when events are triggered
-- @addon Deconlog

local ExpUtil = require("modules/exp_util")
local Event = require("modules/exp_legacy/utils/event") --- @dep utils.event
local Roles = require("modules.exp_legacy.expcore.roles") --- @dep expcore.roles
local format_number = require("util").format_number --- @dep util
local config = require("modules.exp_legacy.config.deconlog") --- @dep config.deconlog

local write_file = helpers.write_file

local filepath = "log/decon.log"
local seconds_time_format = ExpUtil.format_time_factory{ format = "short", hours = true, minutes = true, seconds = true }

local function add_log(data)
    write_file(filepath, data .. "\n", true, 0) -- write data
end

local function get_secs()
    return seconds_time_format(game.tick)
end

local function pos_to_string(pos)
    return tostring(pos.x) .. "," .. tostring(pos.y)
end

local function pos_to_gps_string(pos, surface_name)
    return "[gps=" .. string.format("%.1f", pos.x) .. "," .. string.format("%.1f", pos.y) .. "," .. surface_name "]"
end

--- Print a message to all players who match the value of admin
local function print_to_players(admin, message)
    for _, player in ipairs(game.connected_players) do
        if player.admin == admin then
            player.print(message)
        end
    end
end

Event.on_init(function()
    write_file(filepath, "\n", false, 0) -- write data
end)

if config.decon_area then
    Event.add(defines.events.on_player_deconstructed_area, function(e)
        if e.alt then
            return
        end

        local player = game.players[e.player_index]

        if Roles.player_has_flag(player, "deconlog-bypass") then
            return
        end

        local items = e.surface.find_entities_filtered{ area = e.area, force = player.force }

        if #items > 250 then
            print_to_players(true, {
                "deconlog.decon",
                player.name,
                pos_to_gps_string(e.area.left_top, e.surface.name),
                pos_to_gps_string(e.area.right_bottom, e.surface.name),
                format_number(#items, false),
            })
        end

        add_log(get_secs() .. "," .. player.name .. ",decon_area," .. e.surface.name .. "," .. pos_to_string(e.area.left_top) .. "," .. pos_to_string(e.area.right_bottom))
    end)
end

if config.built_entity then
    Event.add(defines.events.on_built_entity, function(e)
        if not e.player_index then return end
        local player = game.players[e.player_index]
        if Roles.player_has_flag(player, "deconlog-bypass") then
            return
        end
        local ent = e.entity
        add_log(get_secs() .. "," .. player.name .. ",built_entity," .. ent.name .. "," .. pos_to_string(ent.position) .. "," .. tostring(ent.direction) .. "," .. tostring(ent.orientation))
    end)
end

if config.mined_entity then
    Event.add(defines.events.on_player_mined_entity, function(e)
        local player = game.players[e.player_index]
        if Roles.player_has_flag(player, "deconlog-bypass") then
            return
        end
        local ent = e.entity
        add_log(get_secs() .. "," .. player.name .. ",mined_entity," .. ent.name .. "," .. pos_to_string(ent.position) .. "," .. tostring(ent.direction) .. "," .. tostring(ent.orientation))
    end)
end

if config.fired_rocket or config.fired_explosive_rocket or config.fired_nuke then
    Event.add(defines.events.on_player_ammo_inventory_changed, function(e)
        local player = game.players[e.player_index]
        if Roles.player_has_flag(player, "deconlog-bypass") then
            return
        end
        if player.character then
            local ammo_inv = player.get_inventory(defines.inventory.character_ammo) --- @cast ammo_inv -nil
            local item = ammo_inv[player.character.selected_gun_index]
            local action_name
            if not item or not item.valid or not item.valid_for_read then
                return
            end
            if config.fired_rocket and item.name == "rocket" then
                action_name = ",shot-rocket,"
            elseif config.fired_explosive_rocket and item.name == "explosive-rocket" then
                action_name = ",shot-explosive-rocket,"
            elseif config.fired_nuke and item.name == "atomic-bomb" then
                action_name = ",shot-nuke,"
            else
                return
            end
            add_log(get_secs() .. "," .. player.name .. action_name .. pos_to_string(player.physical_position) .. "," .. pos_to_string(player.shooting_state.position))
        end
    end)
end
