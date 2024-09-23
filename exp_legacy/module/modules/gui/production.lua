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
    local _i, _j, m, i, f = string.format('%.1f', n):find('([-]?)(%d+)([.]?%d*)')
    i = i:reverse():gsub('(%d%d%d)', '%1,')

    if f ~= '' then
        return m .. i:reverse():gsub('^,', '') .. f
    else
        return m .. i:reverse():gsub('^,', '') .. '.0'
    end
end

--- Display group
-- @element production_data_group
local production_data_group =
Gui.element(function(_definition, parent, i)
    local item

    if i == 0 then
        item = parent.add{
            type = 'drop-down',
            name = 'production_0_e',
            items = {'5s', '1m', '10m', '1h', '10h'},
            selected_index = 3
        }
        item.style.width = 80

    else
        item = parent.add{
            type = 'choose-elem-button',
            name = 'production_' .. i .. '_e',
            elem_type = 'item',
            style = 'slot_button'
        }
        item.style.height = 32
        item.style.width = 32
    end

    local data_1 = parent.add{
        type = 'label',
        name = 'production_' .. i .. '_1',
        caption = '0.0',
        style = 'heading_2_label'
    }
    data_1.style.width = 90
    data_1.style.horizontal_align = 'right'
    data_1.style.font_color = font_color[1]

    local data_2 = parent.add{
        type = 'label',
        name = 'production_' .. i .. '_2',
        caption = '0.0',
        style = 'heading_2_label'
    }
    data_2.style.width = 90
    data_2.style.horizontal_align = 'right'
    data_2.style.font_color = font_color[2]

    local data_3 = parent.add{
        type = 'label',
        name = 'production_' .. i .. '_3',
        caption = '0.0',
        style = 'heading_2_label'
    }
    data_3.style.width = 90
    data_3.style.horizontal_align = 'right'
    data_3.style.font_color = font_color[1]

    return item
end)

--- A vertical flow containing all the production data
-- @element production_data_set
local production_data_set =
Gui.element(function(_, parent, name)
    local production_set = parent.add{type='flow', direction='vertical', name=name}
    local disp = Gui.scroll_table(production_set, 350, 4, 'disp')

    production_data_group(disp, 0)

    disp['production_0_1'].caption = {'production.label-prod'}
    disp['production_0_2'].caption = {'production.label-con'}
    disp['production_0_3'].caption = {'production.label-bal'}

    for i=1, 8 do
        production_data_group(disp, i)
    end

    return production_set
end)

production_container =
Gui.element(function(definition, parent)
    local container = Gui.container(parent, definition.name, 350)

    production_data_set(container, 'production_st')

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
        local precision_value = precision[frame.container['production_st'].disp.table['production_0_e'].selected_index]
        local table = frame.container['production_st'].disp.table

        for i=1, 8 do
            local production_prefix = 'production_' .. i
            local item = table[production_prefix .. '_e'].elem_value

            if item then
                local add = stat.get_flow_count{name=item, input=true, precision_index=precision_value, count=false} / 60
                local minus = stat.get_flow_count{name=item, input=false, precision_index=precision_value, count=false} / 60
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
