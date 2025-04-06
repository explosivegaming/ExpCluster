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
--- @param reset boolean?
local function apply_bonus(player, reset)
    if reset or not Roles.player_allowed(player, "gui/bonus") then
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

local bonus_data_score_limit = {}
local function get_bonus_score_limit(player)
    if not bonus_data_score_limit[player] then
        bonus_data_score_limit[player] = math.floor(config.pts.base * (1 + config.pts.increase_percentage_per_role_level * (Roles.get_role_by_name(config.pts.role_name).index - Roles.get_player_highest_role(player).index)))
    end
    return bonus_data_score_limit[player]
end

--- Control label for the bonus points available
-- @element bonus_gui_control_pts
local bonus_gui_control_pts = Gui.element("bonus_gui_control_pts")
    :draw{
        type = "label",
        name = Gui.property_from_name,
        caption = { "bonus.control-pts-a" },
        style = "heading_2_label",
    }:style{
        width = config.gui_display_width["half"],
    }

local bonus_gui_control_pts_count = Gui.element("bonus_gui_control_pts_count")
    :draw{
        type = "progressbar",
        name = Gui.property_from_name,
        caption = "0 / 0",
        value = 0,
        style = "electric_satisfaction_statistics_progressbar",
    }:style{
        width = config.gui_display_width["half"],
        font = "heading-2",
        color = { 1, 0, 0 },
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
            disp[disp[s].tags.counter].caption = (config.player_bonus[v].is_percentage and (format_number(disp[s].slider_value * 100, false) .. " %")) or format_number(disp[s].slider_value, false)
        end

        local slider = disp["bonus_display_personal_battery_recharge_slider"]
        slider.slider_value = config.player_special_bonus["personal_battery_recharge"].value
        disp[slider.tags.counter].caption = format_number(slider.slider_value, false)

        local n = bonus_gui_pts_needed(player)
        local limit = get_bonus_score_limit(player)
        element.parent[bonus_gui_control_pts_count.name].caption = n .. " / " .. limit
        element.parent[bonus_gui_control_pts_count.name].value = n / limit
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
        local limit = get_bonus_score_limit(player)
        element.parent[bonus_gui_control_pts_count.name].caption = n .. " / " .. limit
        element.parent[bonus_gui_control_pts_count.name].value = n / limit

        if n <= limit then
            apply_bonus(player)
        end
    end)

--- A vertical flow containing all the bonus control
-- @element bonus_control_set
local bonus_control_set = Gui.element("bonus_control_set")
    :draw(function(_, parent, name)
        local bonus_set = parent.add{ type = "flow", direction = "vertical", name = name }
        local disp = Gui.elements.scroll_table(bonus_set, config.gui_display_width["half"] * 2, 2, "disp")

        bonus_gui_control_pts(disp)
        bonus_gui_control_pts_count(disp)
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
            caption = (bonus.is_percentage and format_number(bonus.value * 100, false) .. " %") or format_number(bonus.value, false),
            style = "heading_2_label",
        }
        count.style.width = config.gui_display_width["count"]

        return slider
    end)
    :on_value_changed(function(def, player, element)
        element.parent[element.tags.counter].caption = (element.tags.is_percentage and format_number(element.slider_value * 100, false) .. " %") or format_number(element.slider_value, false)
        local container = Gui.get_left_element(bonus_container, player)
        local disp = container.frame["bonus_st_1"].disp.table
        local n = bonus_gui_pts_needed(player)
        local limit = get_bonus_score_limit(player)
        disp[bonus_gui_control_pts_count.name].caption = n .. " / " .. limit
        disp[bonus_gui_control_pts_count.name].value = n / limit
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

        bonus_gui_slider(disp, "bonus_display_personal_battery_recharge", { "bonus.display-personal-battery-recharge" }, { "bonus.display-personal-battery-recharge-tooltip" }, config.player_special_bonus["personal_battery_recharge"])

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
        local limit = get_bonus_score_limit(player)
        disp[bonus_gui_control_pts_count.name].caption = n .. " / " .. limit
        disp[bonus_gui_control_pts_count.name].value = n / limit

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

local function recalculate_bonus(event)
    local player = game.players[event.player_index]
    if event.name == Roles.events.on_role_assigned or event.name == Roles.events.on_role_unassigned then
        -- If the player's roles changed then we need to recalculate their limit
        bonus_data_score_limit[player] = nil
    end

    local container = Gui.get_left_element(bonus_container, player)
    local disp = container.frame["bonus_st_1"].disp.table
    local n = bonus_gui_pts_needed(player)
    local limit = get_bonus_score_limit(player)
    disp[bonus_gui_control_pts_count.name].caption = n .. " / " .. limit
    disp[bonus_gui_control_pts_count.name].value = n / limit

    apply_bonus(player, n > limit)
end

Event.add(Roles.events.on_role_assigned, recalculate_bonus)
Event.add(Roles.events.on_role_unassigned, recalculate_bonus)
Event.add(defines.events.on_player_respawned, recalculate_bonus)

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
