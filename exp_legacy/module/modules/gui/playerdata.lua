---- module pd
-- @gui PlayerData

local ExpUtil = require("modules/exp_util")
local Gui = require("modules.exp_legacy.expcore.gui") --- @dep expcore.gui
local Roles = require("modules.exp_legacy.expcore.roles") --- @dep expcore.roles
local Event = require("modules/exp_legacy/utils/event") --- @dep utils.event
local PlayerData = require("modules.exp_legacy.expcore.player_data") --- @dep expcore.player_data
require("modules.exp_legacy.modules.data.statistics")
local format_number = require("util").format_number --- @dep util

local pd_container
local label_width = {
    ["name"] = 135,
    ["count"] = 105,
    ["total"] = 480,
}

local short_time_format = ExpUtil.format_time_factory_locale{ format = "short", coefficient = 3600, hours = true, minutes = true }

local function format_number_n(n)
    return format_number(math.floor(n)) .. string.format("%.2f", n % 1):sub(2)
end

local PlayerStats = PlayerData.Statistics
local computed_stats = {
    DamageDeathRatio = {
        default = format_number_n(0),
        calculate = function(player_name)
            return format_number_n(PlayerStats["DamageDealt"]:get(player_name, 0) / PlayerStats["Deaths"]:get(player_name, 1))
        end,
    },
    KillDeathRatio = {
        default = format_number_n(0),
        calculate = function(player_name)
            return format_number_n(PlayerStats["Kills"]:get(player_name, 0) / PlayerStats["Deaths"]:get(player_name, 1))
        end,
    },
    SessionTime = {
        default = short_time_format(0),
        calculate = function(player_name)
            return short_time_format((PlayerStats["Playtime"]:get(player_name, 0) - PlayerStats["AfkTime"]:get(player_name, 0)) / PlayerStats["JoinCount"]:get(player_name, 1))
        end,
    },
    BuildRatio = {
        default = format_number_n(0),
        calculate = function(player_name)
            return format_number_n(PlayerStats["MachinesBuilt"]:get(player_name, 0) / PlayerStats["MachinesRemoved"]:get(player_name, 1))
        end,
    },
    RocketPerHour = {
        default = format_number_n(0),
        calculate = function(player_name)
            return format_number_n(PlayerStats["RocketsLaunched"]:get(player_name, 0) * 60 / PlayerStats["Playtime"]:get(player_name, 1))
        end,
    },
    TreeKillPerMinute = {
        default = format_number_n(0),
        calculate = function(player_name)
            return format_number_n(PlayerStats["TreesDestroyed"]:get(player_name, 0) / PlayerStats["Playtime"]:get(player_name, 1))
        end,
    },
    NetPlayTime = {
        default = short_time_format(0),
        calculate = function(player_name)
            return short_time_format((PlayerStats["Playtime"]:get(player_name, 0) - PlayerStats["AfkTime"]:get(player_name, 0)))
        end,
    },
    AFKTimeRatio = {
        default = format_number_n(0),
        calculate = function(player_name)
            return format_number_n(PlayerStats["AfkTime"]:get(player_name, 0) * 100 / PlayerStats["Playtime"]:get(player_name, 1))
        end,
    },
}

local label =
    Gui.element(function(_, parent, width, caption, tooltip, name)
        local new_label = parent.add{
            type = "label",
            caption = caption,
            tooltip = tooltip,
            name = name,
            style = "heading_2_label",
        }

        new_label.style.width = width
        return new_label
    end)

local pd_data_set =
    Gui.element(function(_, parent, name)
        local pd_data_set = parent.add{ type = "flow", direction = "vertical", name = name }
        local disp = Gui.scroll_table(pd_data_set, label_width["total"], 4, "disp")

        for _, stat_name in pairs(PlayerData.Statistics.metadata.display_order) do
            local child = PlayerData.Statistics[stat_name]
            local metadata = child.metadata
            local value = metadata.stringify_short and metadata.stringify_short(0) or metadata.stringify and metadata.stringify(0) or format_number(0)
            label(disp, label_width["name"], metadata.name or { "exp-statistics." .. stat_name }, metadata.tooltip or { "exp-statistics." .. stat_name .. "-tooltip" })
            label(disp, label_width["count"], { "readme.data-format", value, metadata.unit or "" }, metadata.value_tooltip or { "exp-statistics." .. stat_name .. "-tooltip" }, stat_name)
        end

        for stat_name, data in pairs(computed_stats) do
            label(disp, label_width["name"], { "exp-statistics." .. stat_name }, { "exp-statistics." .. stat_name .. "-tooltip" })
            label(disp, label_width["count"], { "readme.data-format", data.default, "" }, { "exp-statistics." .. stat_name .. "-tooltip" }, stat_name)
        end

        return pd_data_set
    end)

local function pd_update(table, player_name)
    for _, stat_name in pairs(PlayerData.Statistics.metadata.display_order) do
        local child = PlayerData.Statistics[stat_name]
        local metadata = child.metadata
        local value = child:get(player_name)
        if metadata.stringify_short then
            value = metadata.stringify_short(value or 0)
        elseif metadata.stringify then
            value = metadata.stringify(value or 0)
        else
            value = format_number(value or 0)
        end
        table[stat_name].caption = { "readme.data-format", value, metadata.unit or "" }
    end

    for stat_name, data in pairs(computed_stats) do
        table[stat_name].caption = { "readme.data-format", data.calculate(player_name), "" }
    end
end

local pd_username_player =
    Gui.element(function(definition, parent, player_list)
        return parent.add{
            name = definition.name,
            type = "drop-down",
            items = player_list,
            selected_index = #player_list > 0 and 1,
        }
    end)
    :style{
        horizontally_stretchable = true,
    }:on_selection_changed(function(_, element, _)
        local player_name = game.connected_players[element.selected_index]
        local table = element.parent.parent.parent.parent["pd_st_2"].disp.table
        pd_update(table, player_name)
    end)
    :static_name(Gui.unique_static_name)

local pd_username_update =
    Gui.element{
        type = "button",
        name = Gui.unique_static_name,
        caption = "update",
    }:style{
        width = 128,
    }:on_click(function(_, element, _)
        local player_index = element.parent[pd_username_player.name].selected_index

        if player_index > 0 then
            local player_name = game.connected_players[player_index]
            local table = element.parent.parent.parent.parent["pd_st_2"].disp.table
            pd_update(table, player_name)
        end
    end)

local pd_username_set =
    Gui.element(function(_, parent, name, player_list)
        local pd_username_set = parent.add{ type = "flow", direction = "vertical", name = name }
        local disp = Gui.scroll_table(pd_username_set, label_width["total"], 2, "disp")

        pd_username_player(disp, player_list)
        pd_username_update(disp)

        return pd_username_set
    end)

pd_container =
    Gui.element(function(definition, parent)
        local container = Gui.container(parent, definition.name, label_width["total"])
        local player_list = {}

        for _, player in pairs(game.connected_players) do
            table.insert(player_list, player.name)
        end

        pd_username_set(container, "pd_st_1", player_list)
        pd_data_set(container, "pd_st_2")

        return container.parent
    end)
    :static_name(Gui.unique_static_name)
    :add_to_left_flow()

Gui.left_toolbar_button("item/power-armor-mk2", "Player Data GUI", pd_container, function(player)
    return Roles.player_allowed(player, "gui/playerdata")
end)

local function gui_player_list_update()
    local player_list = {}

    for _, player in pairs(game.connected_players) do
        table.insert(player_list, player.name)
    end

    for _, player in pairs(game.connected_players) do
        local frame = Gui.get_left_element(player, pd_container)
        frame.container["pd_st_1"].disp.table[pd_username_player.name].items = player_list
    end
end

Event.add(defines.events.on_player_joined_game, gui_player_list_update)
Event.add(defines.events.on_player_left_game, gui_player_list_update)
