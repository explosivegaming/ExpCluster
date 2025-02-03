--[[-- Gui Module - Bonus
    @gui Bonus
    @alias bonus_container
]]

local Gui = require("modules/exp_gui")
local Event = require("modules/exp_legacy/utils/event") --- @dep utils.event
local Roles = require("modules.exp_legacy.expcore.roles") --- @dep expcore.roles
local config = require("modules.exp_legacy.config.bonus") --- @dep config.bonus
local vlayer = require("modules.exp_legacy.modules.control.vlayer")
local format_number = require("util").format_number --- @dep util
local bonus_container

--- @param player LuaPlayer
--- @param container LuaGuiElement?
--- @return number
local function bonus_gui_pts_needed(player, container)
    container = container or Gui.get_left_element(bonus_container, player)
    local disp = container.frame["bonus_st_2"].disp.table
    local total = 0

    for k, v in pairs(config.conversion) do
        total = total + (disp["bonus_display_" .. k .. "_slider"].slider_value / config.player_bonus[v].cost_scale * config.player_bonus[v].cost)
    end

    total = total + (
        disp["bonus_display_personal_battery_recharge_slider"].slider_value
        / config.player_special_bonus["personal_battery_recharge"].cost_scale
        * config.player_special_bonus["personal_battery_recharge"].cost
    )

    return total
end

--- @param player LuaPlayer
local function apply_bonus(player)
    if not Roles.player_allowed(player, "gui/bonus") then
        for k, v in pairs(config.player_bonus) do
            player[k] = 0

            if v.combined_bonus then
                for i = 1, #v.combined_bonus do
                    player[v.combined_bonus[i]] = 0
                end
            end
        end

        return
    end

    if not player.character then
        return
    end

    local container = Gui.get_left_element(bonus_container, player)
    local disp = container.frame["bonus_st_2"].disp.table

    for k, v in pairs(config.conversion) do
        player[v] = disp["bonus_display_" .. k .. "_slider"].slider_value

        if config.player_bonus[v].combined_bonus then
            for i = 1, #config.player_bonus[v].combined_bonus do
                player[config.player_bonus[v].combined_bonus[i]] = disp["bonus_display_" .. k .. "_slider"].slider_value
            end
        end
    end
end

local function apply_periodic_bonus(player)
    if not Roles.player_allowed(player, "gui/bonus") then
        return
    end

    if not player.character then
        return
    end

    local container = Gui.get_left_element(bonus_container, player)
    local disp = container.frame["bonus_st_2"].disp.table

    if vlayer.get_statistics()["energy_sustained"] > 0 then
        local armor = player.get_inventory(defines.inventory.character_armor)

        if armor and armor[1] and armor[1].valid_for_read and armor[1].grid then
            local armor_grid = armor[1].grid

            if armor_grid and armor_grid.available_in_batteries and armor_grid.battery_capacity and armor_grid.available_in_batteries < armor_grid.battery_capacity then
                local slider = disp["bonus_display_personal_battery_recharge_slider"].slider_value * 100000 * config.player_special_bonus_rate / 6

                for i = 1, #armor_grid.equipment do
                    if armor_grid.equipment[i].energy < armor_grid.equipment[i].max_energy then
                        local energy_required = math.min(math.floor(armor_grid.equipment[i].max_energy - armor_grid.equipment[i].energy), vlayer.get_statistics()["energy_storage"], slider)
                        armor_grid.equipment[i].energy = armor_grid.equipment[i].energy + energy_required
                        vlayer.energy_changed(-energy_required)

                        slider = slider - energy_required
                    end
                end
            end
        end
    end
end

--- Control label for the bonus points available
-- @element bonus_gui_control_pts_a
local bonus_gui_control_pts_a = Gui.element("bonus_gui_control_pts_a")
    :draw{
        type = "label",
        name = Gui.property_from_name,
        caption = { "bonus.control-pts-a" },
        style = "heading_2_label",
    }:style{
        width = config.gui_display_width["half"],
    }

local bonus_gui_control_pts_a_count = Gui.element("bonus_gui_control_pts_a_count")
    :draw{
        type = "label",
        name = Gui.property_from_name,
        caption = config.pts.base,
        style = "heading_2_label",
    }:style{
        width = config.gui_display_width["half"],
    }

--- Control label for the bonus points needed
-- @element bonus_gui_control_pts_n
local bonus_gui_control_pts_n = Gui.element("bonus_gui_control_pts_n")
    :draw{
        type = "label",
        name = Gui.property_from_name,
        caption = { "bonus.control-pts-n" },
        style = "heading_2_label",
    }:style{
        width = config.gui_display_width["half"],
    }

local bonus_gui_control_pts_n_count = Gui.element("bonus_gui_control_pts_n_count")
    :draw{
        type = "label",
        name = Gui.property_from_name,
        caption = "0",
        style = "heading_2_label",
    }:style{
        width = config.gui_display_width["half"],
    }

--- Control label for the bonus points remaining
-- @element bonus_gui_control_pts_r
local bonus_gui_control_pts_r = Gui.element("bonus_gui_control_pts_r")
    :draw{
        type = "label",
        name = Gui.property_from_name,
        caption = { "bonus.control-pts-r" },
        style = "heading_2_label",
    }:style{
        width = config.gui_display_width["half"],
    }

local bonus_gui_control_pts_r_count = Gui.element("bonus_gui_control_pts_r_count")
    :draw{
        type = "label",
        name = Gui.property_from_name,
        caption = "0",
        style = "heading_2_label",
    }:style{
        width = config.gui_display_width["half"],
    }

--- A button used for pts calculations
-- @element bonus_gui_control_refresh
local bonus_gui_control_reset = Gui.element("bonus_gui_control_reset")
    :draw{
        type = "button",
        name = Gui.property_from_name,
        caption = { "bonus.control-reset" },
    }:style{
        width = config.gui_display_width["half"],
    }:on_click(function(def, player, element)
        local container = Gui.get_left_element(bonus_container, player)
        local disp = container.frame["bonus_st_2"].disp.table

        for k, v in pairs(config.conversion) do
            local s = "bonus_display_" .. k .. "_slider"
            disp[s].slider_value = config.player_bonus[v].value

            if config.player_bonus[v].is_percentage then
                disp[disp[s].tags.counter].caption = format_number(disp[s].slider_value * 100, false) .. " %"
            else
                disp[disp[s].tags.counter].caption = format_number(disp[s].slider_value, false)
            end
        end

        local slider = disp["bonus_display_personal_battery_recharge_slider"]
        slider.slider_value = config.player_special_bonus["personal_battery_recharge"].value
        disp[slider.tags.counter].caption = format_number(slider.slider_value, false)

        local r = bonus_gui_pts_needed(player)
        element.parent[bonus_gui_control_pts_n_count.name].caption = r
        element.parent[bonus_gui_control_pts_r_count.name].caption = tonumber(element.parent[bonus_gui_control_pts_a_count.name].caption) - r
    end)

--- A button used for pts apply
-- @element bonus_gui_control_apply
local bonus_gui_control_apply = Gui.element("bonus_gui_control_apply")
    :draw{
        type = "button",
        name = Gui.property_from_name,
        caption = { "bonus.control-apply" },
    }:style{
        width = config.gui_display_width["half"],
    }:on_click(function(def, player, element)
        local n = bonus_gui_pts_needed(player)
        element.parent[bonus_gui_control_pts_n_count.name].caption = n
        local r = tonumber(element.parent[bonus_gui_control_pts_a_count.name].caption) - n
        element.parent[bonus_gui_control_pts_r_count.name].caption = r

        if r >= 0 then
            apply_bonus(player)
        end
    end)

--- A vertical flow containing all the bonus control
-- @element bonus_control_set
local bonus_control_set = Gui.element("bonus_control_set")
    :draw(function(_, parent, name)
        local bonus_set = parent.add{ type = "flow", direction = "vertical", name = name }
        local disp = Gui.elements.scroll_table(bonus_set, config.gui_display_width["half"] * 2, 2, "disp")

        bonus_gui_control_pts_a(disp)
        bonus_gui_control_pts_a_count(disp)

        bonus_gui_control_pts_n(disp)
        bonus_gui_control_pts_n_count(disp)

        bonus_gui_control_pts_r(disp)
        bonus_gui_control_pts_r_count(disp)

        bonus_gui_control_reset(disp)
        bonus_gui_control_apply(disp)

        return bonus_set
    end)

--- Display group
-- @element bonus_gui_slider
local bonus_gui_slider = Gui.element("bonus_gui_slider")
    :draw(function(def, parent, name, caption, tooltip, bonus)
        local label = parent.add{
            type = "label",
            caption = caption,
            tooltip = tooltip,
            style = "heading_2_label",
        }
        label.style.width = config.gui_display_width["label"]

        local value = bonus.value

        if bonus.is_percentage then
            value = format_number(value * 100, false) .. " %"
        else
            value = format_number(value, false)
        end

        local slider = parent.add{
            type = "slider",
            name = name .. "_slider",
            value = bonus.value,
            maximum_value = bonus.max,
            value_step = bonus.scale,
            discrete_values = true,
            style = "notched_slider",
            tags = {
                counter = name .. "_count",
                is_percentage = bonus.is_percentage,
            },
        }
        slider.style.width = config.gui_display_width["slider"]
        slider.style.horizontally_stretchable = true

        local count = parent.add{
            type = "label",
            name = name .. "_count",
            caption = value,
            style = "heading_2_label",
        }
        count.style.width = config.gui_display_width["count"]

        return slider
    end)
    :on_value_changed(function(def, player, element)
        if element.tags.is_percentage then
            element.parent[element.tags.counter].caption = format_number(element.slider_value * 100, false) .. " %"
        else
            element.parent[element.tags.counter].caption = format_number(element.slider_value, false)
        end

        local r = bonus_gui_pts_needed(player)
        local container = Gui.get_left_element(bonus_container, player)
        local disp = container.frame["bonus_st_1"].disp.table
        disp[bonus_gui_control_pts_n_count.name].caption = r
        disp[bonus_gui_control_pts_r_count.name].caption = tonumber(disp[bonus_gui_control_pts_a_count.name].caption) - r
    end)

--- A vertical flow containing all the bonus data
-- @element bonus_data_set
local bonus_data_set = Gui.element("bonus_data_set")
    :draw(function(_, parent, name)
        local bonus_set = parent.add{ type = "flow", direction = "vertical", name = name }
        local disp = Gui.elements.scroll_table(bonus_set, config.gui_display_width["half"] * 2, 3, "disp")

        for k, v in pairs(config.conversion) do
            bonus_gui_slider(disp, "bonus_display_" .. k, { "bonus.display-" .. k }, { "bonus.display-" .. k .. "-tooltip" }, config.player_bonus[v])
        end

        bonus_gui_slider(disp, "bonus_display_personal_battery_recharge", { "bonus.display-personal-battery-recharge" }, { "bonus.display-personal-battery-recharge-tooltip" },
            config.player_special_bonus["personal_battery_recharge"])

        return bonus_set
    end)

--- The main container for the bonus gui
-- @element bonus_container
bonus_container = Gui.element("bonus_container")
    :draw(function(def, parent)
        local player = Gui.get_player(parent)
        local container = Gui.elements.container(parent, config.gui_display_width["half"] * 2)

        bonus_control_set(container, "bonus_st_1")
        bonus_data_set(container, "bonus_st_2")

        local disp = container["bonus_st_1"].disp.table
        local n = bonus_gui_pts_needed(player, container.parent)
        disp[bonus_gui_control_pts_n_count.name].caption = n
        local r = tonumber(disp[bonus_gui_control_pts_a_count.name].caption) - n
        disp[bonus_gui_control_pts_r_count.name].caption = r

        return container.parent
    end)

--- Add the element to the left flow with a toolbar button
Gui.add_left_element(bonus_container, false)
Gui.toolbar.create_button{
    name = "bonus_toggle",
    left_element = bonus_container,
    sprite = "item/exoskeleton-equipment",
    tooltip = { "bonus.main-tooltip" },
    visible = function(player, element)
        return Roles.player_allowed(player, "gui/bonus")
    end
}

Event.add(defines.events.on_player_created, function(event)
    if event.player_index ~= 1 then
        return
    end

    for k, v in pairs(config.force_bonus) do
        game.players[event.player_index].force[k] = v.value
    end

    for k, v in pairs(config.surface_bonus) do
        game.players[event.player_index].surface[k] = v.value
    end
end)

Event.add(Roles.events.on_role_assigned, function(event)
    apply_bonus(game.players[event.player_index])
end)

Event.add(Roles.events.on_role_unassigned, function(event)
    apply_bonus(game.players[event.player_index])
end)

--- When a player respawns re-apply bonus
Event.add(defines.events.on_player_respawned, function(event)
    local player = game.players[event.player_index]
    local container = Gui.get_left_element(bonus_container, player)
    local disp = container.frame["bonus_st_1"].disp.table
    local n = bonus_gui_pts_needed(player)
    disp[bonus_gui_control_pts_n_count.name].caption = n
    local r = tonumber(disp[bonus_gui_control_pts_a_count.name].caption) - n
    disp[bonus_gui_control_pts_r_count.name].caption = r

    if r >= 0 then
        apply_bonus(player)
    end
end)

--- When a player dies allow them to have instant respawn
Event.add(defines.events.on_player_died, function(event)
    local player = game.players[event.player_index]

    if Roles.player_has_flag(player, "instant-respawn") then
        player.ticks_to_respawn = 120
    end
end)

Event.on_nth_tick(config.player_special_bonus_rate, function(_)
    for _, player in pairs(game.connected_players) do
        if player.character then
            apply_periodic_bonus(player)
        end
    end
end)
