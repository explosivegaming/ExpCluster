---- module pd
-- @gui PlayerData

local Gui = require 'expcore.gui' --- @dep expcore.gui
local Roles = require 'expcore.roles' --- @dep expcore.roles
local Event = require 'utils.event' --- @dep utils.event
local PlayerData = require 'expcore.player_data' --- @dep expcore.player_data
require 'modules.data.statistics'
local format_time = _C.format_time --- @dep expcore.common
local format_number = require('util').format_number --- @dep util

local pd_container
local label_width = {
    ['name'] = 135,
    ['count'] = 105,
    ['total'] = 480
}

local function format_time_short(value)
    return format_time(value*3600, {
        hours=true,
        minutes=true,
        seconds=false
    })
end

local function format_number_n(n)
    return format_number(math.floor(n)) .. string.format('%.2f', n % 1):sub(2)
end

local playerStats = PlayerData.Statistics
local computed_stats = {
    DamageDeathRatio = {
        default = format_number_n(0),
        calculate = function(player_name)
            return format_number_n(playerStats['DamageDealt']:get(player_name, 0) / playerStats['Deaths']:get(player_name, 1))
        end
    },
    KillDeathRatio = {
        default = format_number_n(0),
        calculate = function(player_name)
            return format_number_n(playerStats['Kills']:get(player_name, 0) / playerStats['Deaths']:get(player_name, 1))
        end
    },
    SessionTime = {
        default = format_time_short(0),
        calculate = function(player_name)
            return format_time_short((playerStats['Playtime']:get(player_name, 0) - playerStats['AfkTime']:get(player_name, 0)) / playerStats['JoinCount']:get(player_name, 1))
        end
    },
    BuildRatio = {
        default = format_number_n(0),
        calculate = function(player_name)
            return format_number_n(playerStats['MachinesBuilt']:get(player_name, 0) / playerStats['MachinesRemoved']:get(player_name, 1))
        end
    },
    RocketPerHour = {
        default = format_number_n(0),
        calculate = function(player_name)
            return format_number_n(playerStats['RocketsLaunched']:get(player_name, 0) * 60 / playerStats['Playtime']:get(player_name, 1))
        end
    },
    TreeKillPerMinute = {
        default = format_number_n(0),
        calculate = function(player_name)
            return format_number_n(playerStats['TreesDestroyed']:get(player_name, 0) / playerStats['Playtime']:get(player_name, 1))
        end
    },
    NetPlayTime = {
        default = format_time_short(0),
        calculate = function(player_name)
            return format_time_short((playerStats['Playtime']:get(player_name, 0) - playerStats['AfkTime']:get(player_name, 0)))
        end
    },
    AFKTimeRatio = {
        default = format_number_n(0),
        calculate = function(player_name)
            return format_number_n(playerStats['AfkTime']:get(player_name, 0) * 100 / playerStats['Playtime']:get(player_name, 1))
        end
    },
}

local label =
Gui.element(function(_, parent, width, caption, tooltip, name)
    local new_label = parent.add{
        type = 'label',
        caption = caption,
        tooltip = tooltip,
        name = name,
        style = 'heading_2_label'
    }

    new_label.style.width = width
    return new_label
end)

local pd_data_set =
Gui.element(function(_, parent, name)
    local pd_data_set = parent.add{type='flow', direction='vertical', name=name}
    local disp = Gui.scroll_table(pd_data_set, label_width['total'], 4, 'disp')

    for _, stat_name in pairs(PlayerData.Statistics.metadata.display_order) do
        local child = PlayerData.Statistics[stat_name]
        local metadata = child.metadata
        local value = metadata.stringify_short and metadata.stringify_short(0) or metadata.stringify and metadata.stringify(0) or format_number(0)
        label(disp, label_width['name'], metadata.name or {'exp-statistics.'..stat_name}, metadata.tooltip or {'exp-statistics.'..stat_name..'-tooltip'})
        label(disp, label_width['count'], {'readme.data-format', value, metadata.unit or ''}, metadata.value_tooltip or {'exp-statistics.'..stat_name..'-tooltip'}, stat_name)
    end

    for stat_name, data in pairs(computed_stats) do
        label(disp, label_width['name'], {'exp-statistics.'..stat_name}, {'exp-statistics.'..stat_name..'-tooltip'})
        label(disp, label_width['count'], {'readme.data-format', data.default, ''}, {'exp-statistics.'..stat_name..'-tooltip'}, stat_name)
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
        table[stat_name].caption = {'readme.data-format', value, metadata.unit or ''}
    end

    for stat_name, data in pairs(computed_stats) do
        table[stat_name].caption = {'readme.data-format', data.calculate(player_name), ''}
    end
end

local pd_username_player =
Gui.element(function(definition, parent, player_list)
    return parent.add{
        name = definition.name,
        type = 'drop-down',
        items = player_list,
        selected_index = #player_list > 0 and 1
    }
end)
:style{
    horizontally_stretchable = true
}:on_selection_changed(function(_, element, _)
    local player_name = game.connected_players[element.selected_index]
    local table = element.parent.parent.parent.parent['pd_st_2'].disp.table
    pd_update(table, player_name)
end)
:static_name(Gui.unique_static_name)

local pd_username_update =
Gui.element{
    type = 'button',
    name = Gui.unique_static_name,
    caption = 'update'
}:style{
    width = 128
}:on_click(function(_, element, _)
    local player_index = element.parent[pd_username_player.name].selected_index

    if player_index > 0 then
        local player_name = game.connected_players[player_index]
        local table = element.parent.parent.parent.parent['pd_st_2'].disp.table
        pd_update(table, player_name)
    end
end)

local pd_username_set =
Gui.element(function(_, parent, name, player_list)
    local pd_username_set = parent.add{type='flow', direction='vertical', name=name}
    local disp = Gui.scroll_table(pd_username_set, label_width['total'], 2, 'disp')

    pd_username_player(disp, player_list)
    pd_username_update(disp)

    return pd_username_set
end)

pd_container =
Gui.element(function(definition, parent)
    local container = Gui.container(parent, definition.name, label_width['total'])
    local player_list = {}

    for _, player in pairs(game.connected_players) do
        table.insert(player_list, player.name)
    end

    pd_username_set(container, 'pd_st_1', player_list)
    pd_data_set(container, 'pd_st_2')

    return container.parent
end)
:static_name(Gui.unique_static_name)
:add_to_left_flow()

Gui.left_toolbar_button('item/power-armor-mk2', 'Player Data GUI', pd_container, function(player)
	return Roles.player_allowed(player, 'gui/playerdata')
end)

local function gui_player_list_update()
    local player_list = {}

    for _, player in pairs(game.connected_players) do
        table.insert(player_list, player.name)
    end

    for _, player in pairs(game.connected_players) do
        local frame = Gui.get_left_element(player, pd_container)
        frame.container['pd_st_1'].disp.table[pd_username_player.name].items = player_list
    end
end

Event.add(defines.events.on_player_joined_game, gui_player_list_update)
Event.add(defines.events.on_player_left_game, gui_player_list_update)
