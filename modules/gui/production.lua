---- Production Data
-- @gui Production

local Gui = require 'expcore.gui' --- @dep expcore.gui
local Event = require 'utils.event' --- @dep utils.event
local Roles = require 'expcore.roles' --- @dep expcore.roles

local production_container

local precision = {
    [1] = defines.flow_precision_index.five_seconds,
    [2] = defines.flow_precision_index.one_minute,
    [3] = defines.flow_precision_index.ten_minutes,
    [4] = defines.flow_precision_index.one_hour,
    [5] = defines.flow_precision_index.ten_hours
}

local font_color = {
    -- positive
    [1] = {r = 0.3, g = 1, b = 0.3},
    -- negative
    [2] = {r = 1, g = 0.3, b = 0.3}
}

local function format_n(n)
    local _i, _j, m, i, f = tostring(n):find('([-]?)(%d+)([.]?%d*)')
    i = i:reverse():gsub('(%d%d%d)', '%1,')

    if f ~= '' then
        return m .. i:reverse():gsub('^,', '') .. f
    else
        return m .. i:reverse():gsub('^,', '') .. '.0'
    end
end

local production_time_scale =
Gui.element{
    type = 'drop-down',
    name = Gui.unique_static_name,
    items = {'5s', '1m', '10m', '1h', '10h'},
    selected_index = 3
}:style{
    width = 80
}

local data_1s =
Gui.element{
    type = 'label',
    name = 'production_0_1',
    caption = {'production.label-prod'},
    style = 'heading_1_label'
}:style{
    width = 96,
    font_color = font_color[1],
    horizontal_align = 'right'
}

local data_2s =
Gui.element{
    type = 'label',
    name = 'production_0_2',
    caption = {'production.label-con'},
    style = 'heading_1_label'
}:style{
    width = 96,
    font_color = font_color[2],
    horizontal_align = 'right'
}

local data_3s =
Gui.element{
    type = 'label',
    name = 'production_0_3',
    caption = {'production.label-bal'},
    style = 'heading_1_label'
}:style{
    width = 96,
    font_color = font_color[1],
    horizontal_align = 'right'
}

--- A vertical flow containing all the production control
-- @element production_control_set
local production_control_set =
Gui.element(function(_, parent, name)
    local production_set = parent.add{type='flow', direction='vertical', name=name}
    local disp = Gui.scroll_table(production_set, 368, 4, 'disp')

    production_time_scale(disp)
    data_1s(disp)
    data_2s(disp)
    data_3s(disp)

    return production_set
end)

--- Display group
-- @element production_data_group
local production_data_group =
Gui.element(function(_definition, parent, i)
    local item = parent.add{
        type = 'choose-elem-button',
        name = 'production_' .. i .. '_e',
        elem_type = 'item',
        style = 'slot_button'
    }
    item.style.height = 80
    item.style.width = 80

    local data_1 = parent.add{
        type = 'label',
        name = 'production_' .. i .. '_1',
        caption = '0.0',
        style = 'heading_1_label'
    }
    data_1.style.width = 96
    data_1.style.horizontal_align = 'right'
    data_1.style.font_color = font_color[1]

    local data_2 = parent.add{
        type = 'label',
        name = 'production_' .. i .. '_2',
        caption = '0.0',
        style = 'heading_1_label'
    }
    data_2.style.width = 96
    data_2.style.horizontal_align = 'right'
    data_2.style.font_color = font_color[2]

    local data_3 = parent.add{
        type = 'label',
        name = 'production_' .. i .. '_3',
        caption = '0.0',
        style = 'heading_1_label'
    }
    data_3.style.width = 96
    data_3.style.horizontal_align = 'right'
    data_3.style.font_color = font_color[1]

    return item
end)

--- A vertical flow containing all the production data
-- @element production_data_set
local production_data_set =
Gui.element(function(_, parent, name)
    local production_set = parent.add{type='flow', direction='vertical', name=name}
    local disp = Gui.scroll_table(production_set, 368, 4, 'disp')

    for i=1, 8 do
        production_data_group(disp, i)
    end

    return production_set
end)

production_container =
Gui.element(function(definition, parent)
    local container = Gui.container(parent, definition.name, 368)
    Gui.header(container, {'production.main-tooltip'}, '', true)

    production_control_set(container, 'production_st_1')
    production_data_set(container, 'production_st_2')

    return container.parent
end)
:static_name(Gui.unique_static_name)
:add_to_left_flow()

Gui.left_toolbar_button('entity/assembling-machine-3', {'production.main-tooltip'}, production_container, function(player)
	return Roles.player_allowed(player, 'gui/production')
end)

Event.on_nth_tick(60, function()
    for _, player in pairs(game.connected_players) do
        local frame = Gui.get_left_element(player, production_container)
        local stat = player.force.item_production_statistics
        local precision_value = precision[frame.container['production_st_1'].disp.table[production_time_scale.name].selected_index]
        local table = frame.container['production_st_2'].disp.table

        for i=1, 8 do
            local production_prefix = 'production_' .. i
            local item = table[production_prefix .. '_e'].elem_value

            if item then
                local add = math.floor(stat.get_flow_count{name=item, input=true, precision_index=precision_value, count=false} / 6) / 10
                local minus = math.floor(stat.get_flow_count{name=item, input=false, precision_index=precision_value, count=false} / 6) / 10
                local sum = add - minus

                table[production_prefix .. '_1'].caption = format_n(add)
                table[production_prefix .. '_2'].caption = format_n(minus)
                table[production_prefix .. '_3'].caption = format_n(sum)

                if sum < 0 then
                    table[production_prefix .. '_3'].style.font_color = font_color[2]

                else
                    table[production_prefix .. '_3'].style.font_color = font_color[1]
                end

            else
                table[production_prefix .. '_1'].caption = '0.0'
                table[production_prefix .. '_2'].caption = '0.0'
                table[production_prefix .. '_3'].caption = '0.0'
                table[production_prefix .. '_3'].style.font_color = font_color[1]
            end
        end
    end
end)
