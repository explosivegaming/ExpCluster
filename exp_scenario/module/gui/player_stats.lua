--[[-- Gui - Player Data
Displays the player data for a player
]]

local ExpUtil = require("modules/exp_util")
local Gui = require("modules/exp_gui")
local ElementsExtra = require("modules/exp_scenario/gui/elements")
local Roles = require("modules/exp_legacy/expcore/roles")

require("modules/exp_legacy/modules/data/statistics")
local PlayerData = require("modules/exp_legacy/expcore/player_data")
local PlayerStats = PlayerData.Statistics

--- @class ExpGui_PlayerStats.elements
local Elements = {}

local short_time_format = ExpUtil.format_time_factory_locale{ format = "short", coefficient = 3600, hours = true, minutes = true }

local format_number = require("util").format_number
local function format_number_2dp(n)
    return format_number(math.floor(n), false) .. string.format("%.2f", n % 1):sub(2)
end

local short_time_zero, format_number_zero = short_time_format(0), format_number_2dp(0)

--- @type table<string, { default: LocalisedString, calculate: fun(player: LuaPlayer): LocalisedString }>
local computed_stats = {
    DamageDeathRatio = {
        default = format_number_zero,
        calculate = function(player)
            return format_number_2dp(PlayerStats["DamageDealt"]:get(player, 0) / PlayerStats["Deaths"]:get(player, 1))
        end,
    },
    KillDeathRatio = {
        default = format_number_zero,
        calculate = function(player)
            return format_number_2dp(PlayerStats["Kills"]:get(player, 0) / PlayerStats["Deaths"]:get(player, 1))
        end,
    },
    SessionTime = {
        default = short_time_zero,
        calculate = function(player)
            return short_time_format((PlayerStats["Playtime"]:get(player, 0) - PlayerStats["AfkTime"]:get(player, 0)) / PlayerStats["JoinCount"]:get(player, 1))
        end,
    },
    BuildRatio = {
        default = format_number_zero,
        calculate = function(player)
            return format_number_2dp(PlayerStats["MachinesBuilt"]:get(player, 0) / PlayerStats["MachinesRemoved"]:get(player, 1))
        end,
    },
    RocketPerHour = {
        default = format_number_zero,
        calculate = function(player)
            return format_number_2dp(PlayerStats["RocketsLaunched"]:get(player, 0) * 60 / PlayerStats["Playtime"]:get(player, 1))
        end,
    },
    TreeKillPerMinute = {
        default = format_number_zero,
        calculate = function(player)
            return format_number_2dp(PlayerStats["TreesDestroyed"]:get(player, 0) / PlayerStats["Playtime"]:get(player, 1))
        end,
    },
    NetPlayTime = {
        default = short_time_zero,
        calculate = function(player)
            return short_time_format((PlayerStats["Playtime"]:get(player, 0) - PlayerStats["AfkTime"]:get(player, 0)))
        end,
    },
    AFKTimeRatio = {
        default = format_number_zero,
        calculate = function(player)
            return format_number_2dp(PlayerStats["AfkTime"]:get(player, 0) * 100 / PlayerStats["Playtime"]:get(player, 1))
        end,
    },
    Locale = {
        default = "en",
        calculate = function(player)
            return player.locale
        end,
    },
}

--- Label used for all data in the data table
--- @class ExpGui_PlayerStats.elements.table_label: ExpElement
--- @overload fun(parent: LuaGuiElement, opts: { caption: LocalisedString, tooltip: LocalisedString, width: number })
Elements.table_label = Gui.define("player_stats/table_label")
    :draw{
        type = "label",
        caption = Gui.from_argument("caption"),
        tooltip = Gui.from_argument("tooltip"),
        style = "heading_2_label",
    }
    :style{
        width = Gui.from_argument("width"),
    } --[[ @as any ]]

--- Data table that shows all data for a player
--- @class ExpGui_PlayerStats.elements.player_stats_table: ExpElement
--- @field data table<LuaGuiElement, { [string]: LuaGuiElement }>
--- @overload fun(parent: LuaGuiElement): LuaGuiElement
Elements.player_stats_table = Gui.define("player_stats/data_table")
    :draw(function(def, parent)
        --- @cast def ExpGui_PlayerStats.elements.player_stats_table
        local data_table = Gui.elements.scroll_table(parent, 240, 4)
        local labels = {}

        -- Add all standalone stats
        for _, stat_name in pairs(PlayerData.Statistics.metadata.display_order) do
            local metadata = PlayerData.Statistics[stat_name].metadata
            local value = metadata.stringify_short and metadata.stringify_short(0)
                or metadata.stringify and metadata.stringify(0)
                or format_number(0, false)
            Elements.table_label(data_table, {
                caption = metadata.name or { "exp-statistics." .. stat_name },
                tooltip = metadata.tooltip or { "exp-statistics." .. stat_name .. "-tooltip" },
                width = 135,
            })
            labels[stat_name] = Elements.table_label(data_table, {
                caption = { "readme.data-format", value, metadata.unit or "" },
                tooltip = metadata.value_tooltip or { "exp-statistics." .. stat_name .. "-tooltip" },
                width = 105,
            })
        end

        -- Add all computed stats
        for stat_name, data in pairs(computed_stats) do
            Elements.table_label(data_table, {
                caption = { "exp-statistics." .. stat_name },
                tooltip = { "exp-statistics." .. stat_name .. "-tooltip" },
                width = 135,
            })
            labels[stat_name] = Elements.table_label(data_table, {
                caption = { "readme.data-format", data.default, "" },
                tooltip = { "exp-statistics." .. stat_name .. "-tooltip" },
                width = 105,
            })
        end

        def.data[data_table] = labels
        return data_table
    end) --[[ @as any ]]

--- Refresh a data table with the most recent stats for a player
--- @param data_table LuaGuiElement
--- @param player LuaPlayer
function Elements.player_stats_table.refresh(data_table, player)
    local labels = Elements.player_stats_table.data[data_table]

    -- Update all standalone stats
    for _, stat_name in pairs(PlayerStats.metadata.display_order) do
        local stat = PlayerStats[stat_name]
        local metadata = stat.metadata
        local value = stat:get(player, 0)
        if metadata.stringify_short then
            value = metadata.stringify_short(value)
        elseif metadata.stringify then
            value = metadata.stringify(value)
        else
            value = format_number(value, false)
        end
        labels[stat_name].caption = { "readme.data-format", value, metadata.unit or "" }
    end

    -- Update all computed stats
    for stat_name, data in pairs(computed_stats) do
        labels[stat_name].caption = { "readme.data-format", data.calculate(player), "" }
    end
end

--- Dropdown which sets the target player
--- @class ExpGui_PlayerStats.elements.player_dropdown: ExpElement
--- @field data table<LuaGuiElement, LuaGuiElement>
--- @overload fun(parent: LuaGuiElement, camera: LuaGuiElement): LuaGuiElement
Elements.player_dropdown = Gui.define("player_stats/player_dropdown")
    :track_all_elements()
    :draw(function(def, parent)
        return ElementsExtra.online_player_dropdown(parent)
    end)
    :element_data(
        Gui.from_argument(1)
    )
    :on_selection_state_changed(function(def, player, element, event)
        --- @cast def ExpGui_PlayerStats.elements.player_dropdown
        local data_table = def.data[element]
        local target_player = ElementsExtra.online_player_dropdown.get_selected(element)
        Elements.player_stats_table.refresh(data_table, target_player)
    end) --[[ @as any ]]

--- Refresh all stats tables associated with a player dropdown
function Elements.player_dropdown.refresh_online()
    for _, player_dropdown in Elements.player_dropdown:online_elements() do
        local target_player = ElementsExtra.online_player_dropdown.get_selected(player_dropdown)
        local data_table = Elements.player_dropdown.data[player_dropdown]
        Elements.player_stats_table.refresh(data_table, target_player)
    end
end

--- Container added to the left gui flow
Elements.container = Gui.define("player_stats/container")
    :draw(function(def, parent)
        local container = Gui.elements.container(parent)
        local header = Gui.elements.header(container, { caption = { "exp-gui_player-stats.caption-main" } })
        local data_table = Elements.player_stats_table(container)
        Elements.player_dropdown(header, data_table)
        return Gui.elements.container.get_root_element(container)
    end)

--- Add the element to the left flow with a toolbar button
Gui.add_left_element(Elements.container, false)
Gui.toolbar.create_button{
    name = "toggle_player_stats",
    sprite = "item/power-armor-mk2",
    tooltip = { "exp-gui_player-stats.tooltip-main" },
    left_element = Elements.container,
    visible = function(player, element)
        return Roles.player_allowed(player, "gui/playerdata")
    end
}

return {
    elements = Elements,
    on_nth_tick = {
        [300] = Elements.player_dropdown.refresh_online
    }
}
