--[[-- Gui Module - Autofill
    - Adds a button to enable Autofill
    @gui Autofill
    @alias autofill
]]

local Game = require 'utils.game' -- @dep utils.game
local Gui = require 'expcore.gui' -- @dep expcore.gui
local Roles = require 'expcore.roles' -- @dep expcore.gui
local Global = require 'utils.global' -- @dep utils.global
local config = require 'config.gui.autofill' -- @dep config.gui.autofill
local Event = require 'utils.event' -- @dep utils.event
local table = require 'overrides.table' -- @dep overrides.table

local print_text = Game.print_floating_text -- (surface, position, text, color)

--- Table that stores if autofill is enabled or not
local autofill_player_settings = {}
Global.register(autofill_player_settings, function(tbl)
    autofill_player_settings = tbl
end)

local autofill_container

local function rich_img(type, value)
    return '[img='..type..'/'..value..']'
end

--- Toggle entity section visibility
-- @element toggle_item_button
local toggle_section =
Gui.element{
	type = 'sprite-button',
	sprite = 'utility/expand_dark',
	hovered_sprite = 'utility/expand',
	tooltip = {'autofill.toggle-section-tooltip'},
    name = Gui.unique_static_name
}
:style(Gui.sprite_style(20))
:on_click(function(_, element, _)
	local header_flow = element.parent
	local flow_name = header_flow.caption
	local flow = header_flow.parent.parent[flow_name]
	if Gui.toggle_visible_state(flow) then
        element.sprite = 'utility/collapse_dark'
        element.hovered_sprite = 'utility/collapse'
        element.tooltip = {'autofill.toggle-section-collapse-tooltip'}
	else
        element.sprite = 'utility/expand_dark'
        element.hovered_sprite = 'utility/expand'
        element.tooltip = {'autofill.toggle-section-tooltip'}
    end
end)

--- Toggle enitity button, used for toggling autofill for the specific entity
-- All entity autofill settings will be ignored if its disabled
-- @element entity_toggle
local entity_toggle =
Gui.element(function(_, parent, entity_name)
    return parent.add{
        type = 'sprite-button',
        sprite = 'utility/confirm_slot',
        tooltip = {'autofill.toggle-entity-tooltip', rich_img('item', entity_name)},
        style = 'shortcut_bar_button_green'
    }
end)
:style(Gui.sprite_style(22))
:on_click(function(player, element, _)
    local entity_name = string.match(element.parent.parent.name,'(.*)%-header')
    if not autofill_player_settings[player.name] then return end
    local setting = autofill_player_settings[player.name][entity_name]
    if not setting then return end
    if setting.enabled then
        setting.enabled = false
        element.sprite = 'utility/close_black'
        element.style = 'shortcut_bar_button_red'
    else
        setting.enabled = true
        element.sprite = 'utility/confirm_slot'
        element.style = 'shortcut_bar_button_green'
    end
    -- Correct the button size
    local style = element.style
    style.padding = -2
    style.height = 22
    style.width = 22
end)

--- Draw a section header and main scroll
-- @element autofill_section_container
local section =
Gui.element(function(definition, parent, section_name, table_size)
    -- Draw the header for the section
    local header = Gui.header(
        parent,
        {'autofill.toggle-section-caption', rich_img('item', section_name), {'entity-name.'..section_name}},
        {'autofill.toggle-section-tooltip'},
		true,
		section_name..'-header'
    )

    definition:triggers_events(header.parent.header_label)

	-- Right aligned button to toggle the section
    header.caption = section_name
    entity_toggle(header, section_name)
    toggle_section(header)

    local section_table = parent.add{
        type = 'table',
        name = section_name,
        column_count = table_size
    }

    section_table.visible = false

    return definition:no_events(section_table)
end)
:on_click(function(_, element, event)
    event.element = element.parent.alignment[toggle_section.name]
    toggle_section:raise_event(event)
end)

--- Toggle item button, used for toggling autofill for the specific item
-- @element toggle_item_button
local toggle_item_button =
Gui.element(function(_, parent, item)
    return parent.add{
        type = 'sprite-button',
        sprite = 'item/'..item.name,
        tooltip = {'autofill.toggle-tooltip', rich_img('item', item.name), item.category},
        style = 'shortcut_bar_button_red'
    }
end)
:style(Gui.sprite_style(32, nil, { right_margin = -3 }))
:on_click(function(player, element)
    local item_name = element.parent.tooltip
    local entity_name = element.parent.parent.parent.name
    if not autofill_player_settings[player.name] then return end
    local setting = autofill_player_settings[player.name][entity_name]
    if not setting then return end
    local item = setting.items[item_name]
    if not item then return end
    if item.enabled then
        item.enabled = false
        element.style = 'shortcut_bar_button_red'
    else
        item.enabled = true
        element.style = 'shortcut_bar_button_green'
    end
    -- Correct the button size
    local style = element.style
    style.right_margin = -3
    style.padding = -2
    style.height = 32
    style.width = 32
end)


--- Amount text field for a autofill item
-- @element amount_textfield
local amount_textfield =
Gui.element(function(_, parent, item)
    return parent.add{
        type = 'textfield',
        text = item.amount,
        tooltip = {'autofill.amount-tooltip', item.category },
        clear_and_focus_on_right_click = true,
        numeric = true,
        allow_decimal = false,
        allow_negative = false
    }
end)
:style{
    maximal_width = 40,
    height = 31,
    padding = -2
}
:on_text_changed(function(player, element, _)
    local value = tonumber(element.text)
    if not value then value = 0 end
    local clamped = math.clamp(value, 0, 1000)
    local item_name = element.parent.tooltip
    local entity_name = element.parent.parent.parent.name
    if not autofill_player_settings[player.name] then return end
    local setting = autofill_player_settings[player.name][entity_name]
    if not setting then return end
    local item = setting.items[item_name]
    if not item then return end
    item.amount = clamped
    if clamped ~= value then
        element.text = clamped
        player.print{'autofill.invalid', item.amount, rich_img('item', item.name), rich_img('entity', entity_name) }
        return
    end
end)

--- Autofill setting, contains a button and a textbox
-- @element add_autofill_setting
local add_autofill_setting =
Gui.element(function(_, parent, item)
    local toggle_flow = parent.add{ type = 'flow', name = 'toggle-setting-'..item.name, tooltip = item.name }
    local amount_flow = parent.add{ type = 'flow', name = 'amount-setting-'..item.name, tooltip = item.name }
    toggle_flow.style.padding = 0
    amount_flow.style.padding = 0
    toggle_item_button(toggle_flow, item)
    amount_textfield(amount_flow, item)
end)

--- Autofill setting empty, contains filler button and textfield gui elements
-- @element add_empty_autofill_setting
local add_empty_autofill_setting =
Gui.element(function(_, parent)
    local toggle_element = parent.add{
        type = 'sprite-button'
    }
    toggle_element.style.right_margin = -3
    toggle_element.style.width = 32
    toggle_element.style.height = 32
    toggle_element.enabled = false
    local amount_element = parent.add{
        type = 'textfield'
    }
    amount_element.style.maximal_width = 40
    amount_element.style.height = 31
    amount_element.style.padding = -2
    amount_element.enabled = false
end)


--- Main gui container for the left flow
-- @element autofill_container
autofill_container =
Gui.element(function(definition, parent)
    -- Draw the internal container
    local container = Gui.container(parent, definition.name)
    -- Draw the scroll container
    local scroll_table = Gui.scroll_table(container, 400, 1, 'autofill-scroll-table')
    -- Set the scroll panel to always show the scrollbar (not doing this will result in a changing gui size)
    scroll_table.parent.vertical_scroll_policy = 'always'
    -- Scroll panel has by default padding
    scroll_table.parent.style.padding = 0
    -- Remove the default gap that is added in a table between elements
    scroll_table.style.vertical_spacing = 0
    -- Center the first collumn in the table
    scroll_table.style.column_alignments[1] = 'center'
    -- Loop over each default entity config
    for _, setting in pairs(config.default_entities) do
        local table_sizes = {}
        local tables = {}
        -- Draw a section for the element
        local entity_table = section(scroll_table, setting.entity, 3)
        -- Add some padding around the table
        entity_table.style.padding = 3
        -- Make sure each collumn is alignment top center
        entity_table.style.column_alignments[1] = 'top-center'
        entity_table.style.column_alignments[2] = 'top-center'
        entity_table.style.column_alignments[3] = 'top-center'
        -- Loop over each item category
        for _, category in pairs(config.categories) do
            if not table_sizes[category] then table_sizes[category] = 0 end
            -- Draw table
            local category_table = entity_table.add{
                type = 'table',
                name = category..'-category',
                column_count = 2
            }
            -- Add padding between each item
            category_table.style.vertical_spacing = 1
            tables[category] = category_table
            -- Add item autofill setting gui elements to the table
            for _, item in pairs(setting.items) do
                if item.category == category then
                    add_autofill_setting(category_table, item)
                    table_sizes[category] = table_sizes[category] + 1
                end
            end
        end

        -- Add empty gui elements for the categories with less items than the other categories
        local t = table.get_values(table_sizes)
        table.sort(t)
        local biggest = t[#t]
        for category, size in pairs(table_sizes) do
            for i=biggest-size,1,-1 do
                add_empty_autofill_setting(tables[category])
            end
        end
    end

    -- Return the external container
    return container.parent
end)
:static_name(Gui.unique_static_name)
:add_to_left_flow()

--- Button on the top flow used to toggle autofill container
-- @element autofill_toggle
Gui.left_toolbar_button(config.icon, {'autofill.main-tooltip'}, autofill_container, function(player)
	return Roles.player_allowed(player, 'gui/autofill')
end)

--- When a player is created make sure they have the default autofill settings
Event.add(defines.events.on_player_created, function(event)
    local player = game.players[event.player_index]
    if not autofill_player_settings[player.name] then
        autofill_player_settings[player.name] = table.deep_copy(config.default_entities)
    end
end)

local function entity_build(event)
    -- Check if player exists
    local player = game.players[event.player_index]
    if not player then
        return
    end
    -- Check if the entity is in the config and enabled
    local entity = event.created_entity

    -- Check if player has settings
    if not autofill_player_settings[player.name] then return end

    local entity_settings = autofill_player_settings[player.name][entity.name]
    -- Check if autofill for the entity is enabled
    if not entity_settings then return end
    if not entity_settings.enabled then return end

    -- Get the inventory of the player
    local player_inventory = player.get_main_inventory()

    local text_position = { x = entity.position.x, y = entity.position.y }
    -- Loop over all possible items to insert into the entity
    for _, item in pairs(entity_settings.items) do
        -- Check if the item is enabled or goto next item
        if not item.enabled then goto end_item end

        -- Get the inventory of the entity or goto next item
        local entity_inventory = entity.get_inventory(item.inv)
        if not entity_inventory then goto end_item end

        local preferd_amount = item.amount
        local item_amount = player_inventory.get_item_count(item.name)
        if item_amount ~= 0 then
            local inserted
            text_position.y = text_position.y - 0.5
            local color = { r = 0, g = 255, b = 0, a = 1}
            if item_amount >= preferd_amount then
                -- Can item be inserted? no, goto next item!
                if not entity_inventory.can_insert{name=item.name, count=preferd_amount} then
                    goto end_item
                end
                inserted = entity_inventory.insert{name=item.name, count=preferd_amount}
            else
                inserted = entity_inventory.insert{name=item.name, count=item_amount}
                color = { r = 255, g = 165, b = 0, a = 1}
            end
            player_inventory.remove{name=item.name, count=inserted}
            print_text(entity.surface, text_position, {'autofill.inserted', inserted, rich_img('item', item.name), rich_img('entity', entity.name) }, color)
        end
        ::end_item::
    end
end

Event.add(defines.events.on_built_entity, entity_build)
