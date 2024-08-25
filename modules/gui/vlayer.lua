--[[-- Gui Module - Virtual Layer
    - Adds a virtual layer to store power to save space.
    @gui Virtual Layer
    @alias vlayer_container
]]

local Gui = require 'expcore.gui' --- @dep expcore.gui
local Roles = require 'expcore.roles' --- @dep expcore.roles
local Event = require 'utils.event' --- @dep utils.event
local format_number = require('util').format_number --- @dep util
local config = require 'config.vlayer' --- @dep config.vlayer
local vlayer = require 'modules.control.vlayer'
local Selection = require 'modules.control.selection' --- @dep modules.control.selection
local SelectionConvertArea = 'VlayerConvertChest'

--- Align an aabb to the grid by expanding it
local function aabb_align_expand(aabb)
    return {
        left_top = {x = math.floor(aabb.left_top.x), y = math.floor(aabb.left_top.y)},
        right_bottom = {x = math.ceil(aabb.right_bottom.x), y = math.ceil(aabb.right_bottom.y)}
    }
end

local vlayer_container
local vlayer_gui_control_type
local vlayer_gui_control_list

local vlayer_control_type_list = {
    [1] = 'energy',
    [2] = 'circuit',
    [3] = 'storage_input',
    [4] = 'storage_output'
}

local function pos_to_gps_string(pos)
	return '[gps=' .. string.format('%.1f', pos.x) .. ',' .. string.format('%.1f', pos.y) .. ']'
end

local function format_energy(amount, unit)
    if amount < 1 then
        return '0 ' .. unit
    end

    local suffix = ''
    local suffix_list = {
        ['T'] = 1000000000000,
        ['G'] = 1000000000,
        ['M'] = 1000000,
        ['k'] = 1000
    }

    for letter, limit in pairs (suffix_list) do
        if math.abs(amount) >= limit then
            amount = string.format('%.1f', amount / limit)
            suffix = letter
            break
        end
    end

    local k
    local formatted = amount

    while true do
        formatted, k = string.gsub(formatted, '^(-?%d+)(%d%d%d)', '%1,%2')

        if (k == 0) then
            break
        end
    end

    return formatted .. ' ' .. suffix .. unit
end

--- When an area is selected to add protection to the area
Selection.on_selection(SelectionConvertArea, function(event)
    local area = aabb_align_expand(event.area)
    local player = game.get_player(event.player_index)

    if not player then
        return nil
    end

    local entities = player.surface.find_entities_filtered{area=area, name='steel-chest', force=player.force}
    local frame = Gui.get_left_element(player, vlayer_container)
    local disp = frame.container['vlayer_st_2'].disp.table
    local target = vlayer_control_type_list[disp[vlayer_gui_control_type.name].selected_index]

    if #entities == 0 then
        player.print{'vlayer.steel-chest-detect'}
        return nil

    elseif #entities > 1 then
        player.print{'vlayer.result-unable', {'vlayer.control-type-' .. target:gsub('_', '-')}}
        return nil
    end

    if not entities[1] then
        return nil
    end

    local e = entities[1]
    local e_pos = {x=string.format('%.1f', e.position.x), y=string.format('%.1f', e.position.y)}
    local e_circ = e.circuit_connected_entities

    if not e.get_inventory(defines.inventory.chest).is_empty() then
        player.print{'vlayer.steel-chest-empty'}
        return nil
    end

    if (vlayer.get_interface_counts()[target] >= config.interface_limit[target]) then
        player.print{'vlayer.result-unable', {'vlayer.control-type-energy'}}
        return nil
    end

    e.destroy()

    if target == 'energy' then
        if not vlayer.create_energy_interface(player.surface, e_pos, player) then
            player.print{'vlayer.result-unable', {'vlayer.control-type-energy'}}
            return nil
        end

    elseif target == 'circuit' then
        vlayer.create_circuit_interface(player.surface, e_pos, e_circ, player)

    elseif target == 'storage_input' then
        vlayer.create_input_interface(player.surface, e_pos, e_circ, player)

    elseif target == 'storage_output' then
        vlayer.create_output_interface(player.surface, e_pos, e_circ, player)
    end

    game.print{'vlayer.interface-result', player.name, pos_to_gps_string(e_pos), {'vlayer.result-build'}, {'vlayer.control-type-' .. target:gsub('_', '-')}}
end)

--- Display label for the number of solar panels
-- @element vlayer_gui_display_item_solar_name
local vlayer_gui_display_item_solar_name =
Gui.element{
    type = 'label',
    name = 'vlayer_display_item_solar_name',
    caption = {'vlayer.display-item-solar'},
    style = 'heading_1_label'
}:style{
    width = 200
}

local vlayer_gui_display_item_solar_count =
Gui.element{
    type = 'label',
    name = 'vlayer_display_item_solar_count',
    caption = '0',
    style = 'heading_1_label'
}:style{
    width = 120
}

--- Display label for the number of accumulators
-- @element vlayer_gui_display_item_accumulator_name
local vlayer_gui_display_item_accumulator_name =
Gui.element{
    type = 'label',
    name = 'vlayer_display_item_accumulator_name',
    caption = {'vlayer.display-item-accumulator'},
    style = 'heading_1_label'
}:style{
    width = 200
}

local vlayer_gui_display_item_accumulator_count =
Gui.element{
    type = 'label',
    name = 'vlayer_display_item_accumulator_count',
    caption = '0',
    style = 'heading_1_label'
}:style{
    width = 120
}

--- Display label for the current energy production
-- @element vlayer_gui_display_signal_production_name
local vlayer_gui_display_signal_production_name =
Gui.element{
    type = 'label',
    name = 'vlayer_display_signal_peak_name',
    caption = {'vlayer.display-current-production'},
    tooltip = {'vlayer.display-current-production-tooltip'},
    style = 'heading_1_label'
}:style{
    width = 200
}

local vlayer_gui_display_signal_production_count =
Gui.element{
    type = 'label',
    name = 'vlayer_display_signal_peak_solar_count',
    caption = '0',
    style = 'heading_1_label'
}:style{
    width = 120
}

--- Display label for the sustained energy production
-- @element vlayer_gui_display_signal_sustained_name
local vlayer_gui_display_signal_sustained_name =
Gui.element{
    type = 'label',
    name = 'vlayer_display_signal_sustained_name',
    caption = {'vlayer.display-sustained-production'},
    tooltip = {'vlayer.display-sustained-production-tooltip'},
    style = 'heading_1_label'
}:style{
    width = 200
}

local vlayer_gui_display_signal_sustained_count =
Gui.element{
    type = 'label',
    name = 'vlayer_display_signal_sustained_count',
    caption = '0',
    style = 'heading_1_label'
}:style{
    width = 120
}

--- Display label for the sustained energy capacity
-- @element vlayer_gui_display_signal_capacity_name
local vlayer_gui_display_signal_capacity_name =
Gui.element{
    type = 'label',
    name = 'vlayer_display_signal_max_name',
    caption = {'vlayer.display-max-capacity'},
    tooltip = {'vlayer.display-max-capacity-tooltip'},
    style = 'heading_1_label'
}:style{
    width = 200
}

local vlayer_gui_display_signal_capacity_count =
Gui.element{
    type = 'label',
    name = 'vlayer_display_signal_max_count',
    caption = '0',
    style = 'heading_1_label'
}:style{
    width = 120
}

--- Display label for the current energy in storage
-- @element vlayer_gui_display_signal_current_name
local vlayer_gui_display_signal_current_name =
Gui.element{
    type = 'label',
    name = 'vlayer_display_signal_current_name',
    caption = {'vlayer.display-current-capacity'},
    tooltip = {'vlayer.display-current-capacity-tooltip'},
    style = 'heading_1_label'
}:style{
    width = 200
}

local vlayer_gui_display_signal_current_count =
Gui.element{
    type = 'label',
    name = 'vlayer_display_signal_current_count',
    caption = '0',
    style = 'heading_1_label'
}:style{
    width = 120
}

--- Display label for the remaining surface area
-- @element vlayer_gui_display_signal_remaining_surface_area_name
local vlayer_gui_display_signal_remaining_surface_area_name =
Gui.element{
    type = 'label',
    name = 'vlayer_display_signal_remaining_surface_area_name',
    caption = {'vlayer.display-remaining-surface-area'},
    tooltip = {'vlayer.display-remaining-surface-area-tooltip'},
    style = 'heading_1_label'
}:style{
    width = 200
}

local vlayer_gui_display_signal_remaining_surface_area_count =
Gui.element{
    type = 'label',
    name = 'vlayer_display_signal_remaining_surface_area_count',
    caption = '0',
    style = 'heading_1_label'
}:style{
    width = 120
}

--- A vertical flow containing all the displays labels and their counts
-- @element vlayer_display_set
local vlayer_display_set =
Gui.element(function(_, parent, name)
    local vlayer_set = parent.add{type='flow', direction='vertical', name=name}
    local disp = Gui.scroll_table(vlayer_set, 320, 2, 'disp')

    vlayer_gui_display_item_solar_name(disp)
    vlayer_gui_display_item_solar_count(disp)
    vlayer_gui_display_item_accumulator_name(disp)
    vlayer_gui_display_item_accumulator_count(disp)
    vlayer_gui_display_signal_remaining_surface_area_name(disp)
    vlayer_gui_display_signal_remaining_surface_area_count(disp)
    vlayer_gui_display_signal_production_name(disp)
    vlayer_gui_display_signal_production_count(disp)
    vlayer_gui_display_signal_sustained_name(disp)
    vlayer_gui_display_signal_sustained_count(disp)
    vlayer_gui_display_signal_capacity_name(disp)
    vlayer_gui_display_signal_capacity_count(disp)
    vlayer_gui_display_signal_current_name(disp)
    vlayer_gui_display_signal_current_count(disp)

    return vlayer_set
end)

local function vlayer_gui_list_refresh(player)
    local frame = Gui.get_left_element(player, vlayer_container)
    local disp = frame.container['vlayer_st_2'].disp.table
    local target = disp[vlayer_gui_control_type.name].selected_index
    local full_list = {}

    if target then
        local interface = vlayer.get_interfaces()[vlayer_control_type_list[target]]

        for i=1, vlayer.get_interface_counts()[vlayer_control_type_list[target]], 1 do
            table.insert(full_list, i .. ' X ' .. interface[i].position.x .. ' Y '.. interface[i].position.y)
        end

        disp[vlayer_gui_control_list.name].items = full_list
    end
end

--- A drop down list filter by this type
-- @element vlayer_gui_control_type
vlayer_gui_control_type =
Gui.element{
    type = 'drop-down',
    name = Gui.unique_static_name,
    items = {{'vlayer.control-type-energy'}, {'vlayer.control-type-circuit'}, {'vlayer.control-type-storage-input'}, {'vlayer.control-type-storage-output'}},
    selected_index = 1
}:style{
    width = 160
}:on_selection_changed(function(player, _, _)
    vlayer_gui_list_refresh(player)
end)

--- A drop down list to see the exact item to remove
-- @element vlayer_gui_control_list
vlayer_gui_control_list =
Gui.element{
    type = 'drop-down',
    name = Gui.unique_static_name,
    items = {''},
    selected_index = 1
}:style{
    width = 160
}

--- A button to refresh the remove list
-- @element vlayer_gui_control_refresh
local vlayer_gui_control_refresh =
Gui.element{
    type = 'button',
    name = Gui.unique_static_name,
    caption = {'vlayer.control-refresh'}
}:style{
    width = 160
}:on_click(function(player, _, _)
    vlayer_gui_list_refresh(player)
end)

--- A button to check if the item is the one wanted to remove
-- @element vlayer_gui_control_see
local vlayer_gui_control_see =
Gui.element{
    type = 'button',
    name = Gui.unique_static_name,
    caption = {'vlayer.control-see'}
}:style{
    width = 160
}:on_click(function(player, element, _)
    local target = element.parent[vlayer_gui_control_type.name].selected_index

    if not target then
        return
    end

    local n = element.parent[vlayer_gui_control_list.name].selected_index

    if not n then
        return
    end

    local pos = vlayer.get_interfaces()[vlayer_control_type_list[target]][n].position

    if not pos then
        return
    end

    player.zoom_to_world(pos, 2)
    player.print{'vlayer.result-interface-location', {'vlayer.control-type-' .. vlayer_control_type_list[target]:gsub('_', '-')}, pos_to_gps_string(pos)}
end)

--- A button used to build the vlayer interface
-- @element vlayer_gui_control_build
local vlayer_gui_control_build =
Gui.element{
    type = 'button',
    name = Gui.unique_static_name,
    caption = {'vlayer.control-build'}
}:style{
    width = 160
}:on_click(function(player, _, _)
    if Selection.is_selecting(player, SelectionConvertArea) then
        Selection.stop(player)
    else
        Selection.start(player, SelectionConvertArea)
        player.print{'expcom-waterfill.entered-area-selection'}
    end

    vlayer_gui_list_refresh(player)
end)

--- A button used to remove the vlayer interface
-- @element vlayer_gui_control_remove
local vlayer_gui_control_remove =
Gui.element{
    type = 'button',
    name = Gui.unique_static_name,
    caption = {'vlayer.control-remove'}
}:style{
    width = 160
}:on_click(function(player, element, _)
    local target = element.parent[vlayer_gui_control_type.name].selected_index
    local n = element.parent[vlayer_gui_control_list.name].selected_index

    if n then
        local t = vlayer.get_interfaces()[vlayer_control_type_list[target]]
        local interface_type, interface_position = vlayer.remove_interface(t[n].surface, t[n].position)

        if interface_type then
            game.print{'vlayer.interface-result', player.name, pos_to_gps_string(interface_position), {'vlayer.result-remove'}, {'vlayer.control-type-' .. interface_type:gsub(' ', '-')}}
        end
    end

    vlayer_gui_list_refresh(player)
end)

--- A vertical flow containing all the control buttons
-- @element vlayer_control_set
local vlayer_control_set =
Gui.element(function(_, parent, name)
    local vlayer_set = parent.add{type='flow', direction='vertical', name=name}
    local disp = Gui.scroll_table(vlayer_set, 320, 2, 'disp')

    vlayer_gui_control_type(disp)
    vlayer_gui_control_list(disp)
    vlayer_gui_control_refresh(disp)
    vlayer_gui_control_see(disp)
    vlayer_gui_control_build(disp)
    vlayer_gui_control_remove(disp)

    return vlayer_set
end)

--- The main container for the vlayer gui
-- @element vlayer_container
vlayer_container =
Gui.element(function(definition, parent)
    local player = Gui.get_player_from_element(parent)
    local container = Gui.container(parent, definition.name, 320)

    vlayer_display_set(container, 'vlayer_st_1')
    local control_set = vlayer_control_set(container, 'vlayer_st_2')
    control_set.visible = Roles.player_allowed(player, 'gui/vlayer-edit')

    return container.parent
end)
:static_name(Gui.unique_static_name)
:add_to_left_flow()

--- Button on the top flow used to toggle the task list container
-- @element toggle_left_element
Gui.left_toolbar_button('entity/solar-panel', {'vlayer.main-tooltip'}, vlayer_container, function(player)
	return Roles.player_allowed(player, 'gui/vlayer')
end)

--- Update the visibly of the buttons based on a players roles
local function role_update_event(event)
    local player = game.players[event.player_index]
    local visible = Roles.player_allowed(player, 'gui/vlayer-edit')
    local frame = Gui.get_left_element(player, vlayer_container)
    frame.container['vlayer_st_2'].visible = visible
end

Event.add(Roles.events.on_role_assigned, role_update_event)
Event.add(Roles.events.on_role_unassigned, role_update_event)

Event.on_nth_tick(config.update_tick_gui, function(_)
    local stats = vlayer.get_statistics()
    local items = vlayer.get_items()
    local vlayer_display = {
        [vlayer_gui_display_item_solar_count.name] = format_number(items['solar-panel']),
        [vlayer_gui_display_item_accumulator_count.name] = format_number(items['accumulator']),
        [vlayer_gui_display_signal_remaining_surface_area_count.name] = format_number(stats.remaining_surface_area),
        [vlayer_gui_display_signal_production_count.name] = format_energy(stats.energy_production, 'W'),
        [vlayer_gui_display_signal_sustained_count.name] = format_energy(stats.energy_sustained, 'W'),
        [vlayer_gui_display_signal_capacity_count.name] = format_energy(stats.energy_capacity, 'J'),
        [vlayer_gui_display_signal_current_count.name] = format_energy(stats.energy_storage, 'J'),
    }

    for _, player in pairs(game.connected_players) do
        local frame = Gui.get_left_element(player, vlayer_container)
        local disp = frame.container['vlayer_st_1'].disp.table

        for k, v in pairs(vlayer_display) do
            disp[k].caption = v
        end
    end
end)
