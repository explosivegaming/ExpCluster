local Gui = require "expcore.gui" --- @dep expcore.gui

-- Styles used for sprite buttons
local button_size = 20
local Styles = {
    sprite20 = Gui.sprite_style(20),
    sprite22 = Gui.sprite_style(22)
}

--- Set the style of the fake toolbar element
local function copy_style(src, dst)
    dst.style = src.style.name
    dst.style.height = button_size
    dst.style.width = button_size
    dst.style.padding = -2
end

--- Resets the toolbar to its default state when pressed
-- @element reset_toolbar
local reset_toolbar =
Gui.element {
    type = "sprite-button",
    sprite = "utility/reset",
    style = "shortcut_bar_button_red",
    name = Gui.unique_static_name
}
:style(Gui.sprite_style(22, -1))
:on_click(function(player, element)
    for element_define, authenticator in pairs(Gui.top_elements) do
        local allowed = authenticator
        if type(allowed) == 'function' then allowed = allowed(player) end
        local state = allowed or false
        local container = element.parent.parent.parent
        local checkbox = container.scroll.list[element_define.name].checkbox
        local toolbar_button = Gui.get_top_element(player, element_define)
        toolbar_button.visible = state
        checkbox.state = state
    end
end)

--- Replaces the default method for opening and closing the toolbar
-- @element toggle_toolbar
local toggle_toolbar =
Gui.element {
    type = "sprite-button",
    sprite = "utility/bookmark",
    style = "tool_button",
    auto_toggle = true,
    name = Gui.unique_static_name
}
:style(Styles.sprite22)
:on_click(function(player, element)
    Gui.toggle_top_flow(player, element.toggled)
end)

--- Move an element up the list
-- @element move_up
local move_up =
Gui.element {
    type = "sprite-button",
    sprite = "utility/speed_up",
    name = Gui.unique_static_name
}
:style(Styles.sprite20)

--- Move an element down the list
-- @element move_down
local move_down =
Gui.element {
    type = "sprite-button",
    sprite = "utility/speed_down",
    name = Gui.unique_static_name
}
:style(Styles.sprite20)

--- A flow which represents one item in the toolbar list
-- @element toolbar_list_item
local toolbar_list_item =
Gui.element(function(definition, parent, element_define)
    local flow = parent.add {
        type = "frame",
        style = "shortcut_selection_row",
        name = element_define.name
    }
    flow.style.horizontally_stretchable = true
    flow.style.vertical_align = "center"

    -- Add the button and the icon edit button
    local element = element_define(flow)
    local player = Gui.get_player_from_element(parent)
    local top_element = Gui.get_top_element(player, element_define)
    copy_style(top_element, element)

    -- Add the checkbox that can toggle the visibility
    local checkbox = flow.add{
        type = "checkbox",
        name = "checkbox",
        caption = element_define.tooltip or "None",
        state = top_element.visible or false,
        tags = { top_element_name = element_define.name }
    }
    definition:triggers_events(checkbox)
    checkbox.style.width = 180

    -- Add the buttons used to move the flow up and down
    local move_flow = flow.add{ type = "flow" }
    move_flow.style.horizontal_spacing = 0
    move_up(move_flow)
    move_down(move_flow)

    return definition:no_events(flow)
end)
:on_checked_changed(function(player, element)
    local top_flow = Gui.get_top_flow(player)
    local top_element = top_flow[element.tags.top_element_name]
    local had_visible = Gui.top_flow_has_visible_elements(player)
    top_element.visible = element.state
    -- Check if we are on the edge case between 0 and 1 visible elements
    if element.state and not had_visible then
        Gui.toggle_top_flow(player, true)
        local container = element.parent.parent.parent.parent
        local button = container.header.alignment[toggle_toolbar.name]
        button.toggled = true
        button.enabled = true
    elseif not element.state and not Gui.top_flow_has_visible_elements(player) then
        Gui.toggle_top_flow(player, false)
        local container = element.parent.parent.parent.parent
        local button = container.header.alignment[toggle_toolbar.name]
        button.toggled = false
        button.enabled = false
    end
end)

--- Scrollable list of all toolbar buttons
-- @element toolbar_list
local toolbar_list =
Gui.element(function(_, parent)
    local scroll_pane = parent.add {
        name = "scroll",
        type = "scroll-pane",
        direction = "vertical",
        horizontal_scroll_policy = "never",
        vertical_scroll_policy = "auto",
        style = "scroll_pane_under_subheader"
    }
    scroll_pane.style.horizontally_stretchable = true
    scroll_pane.style.padding = 0
    scroll_pane.style.maximal_height = 224

    local flow = scroll_pane.add {
        name = "list",
        type = "flow",
        direction = "vertical"
    }
    flow.style.vertical_spacing = 0
    flow.style.horizontally_stretchable = true

    return flow
end)

--- Main toolbar container for the left flow
-- @element toolbar_container
local toolbar_container =
Gui.element(function(definition, parent)
    -- Draw the internal container
    local container = Gui.container(parent, definition.name, 268)
    container.style.maximal_width = 268
    container.style.minimal_width = 268

    -- Draw the header
    local player = Gui.get_player_from_element(parent)
    local header = Gui.header(container, "Toolbar", {"", "Change Me"}, true)

    -- Draw the toolbar control buttons
    local toggle_element = toggle_toolbar(header)
    toggle_element.toggled = Gui.get_top_flow(player).visible
    reset_toolbar(header)

    -- Draw toolbar list element
    local list_element = toolbar_list(container)

    for element_define, authenticator in pairs(Gui.top_elements) do
        -- Ensure the element exists
        local element = list_element[element_define.name]
        if not element then
            element = toolbar_list_item(list_element, element_define)
        end

        -- Set the visible state
        local allowed = authenticator
        if type(allowed) == 'function' then allowed = allowed(player) end
        element.visible = allowed or false
    end

    -- Return the external container
    return container.parent
end)
:static_name(Gui.unique_static_name)
:add_to_left_flow(true)

--- For all top element, register an on click which will copy their style
for element_define, _ in pairs(Gui.top_elements) do
    local prev_handler = element_define[Gui.events.on_toolbar_button_toggled]
    element_define:on_event(Gui.events.on_toolbar_button_toggled, function(player, element, event)
        if prev_handler then prev_handler(player, element, event) end -- Kind of hacky but works
        local frame = Gui.get_left_element(player, toolbar_container)
        if not frame then return end -- Gui might not be loaded yet
        local button = frame.container.scroll.list[element_define.name][element_define.name]
        local toolbar_button = Gui.get_top_element(player, element_define)
        copy_style(toolbar_button, button)
    end)
end

--- Overwrite the default toggle behaviour and instead toggle this menu
Gui.core_defines.hide_top_flow:on_click(function(player, _, _)
    Gui.toggle_left_element(player, toolbar_container)
end)

--- Overwrite the default toggle behaviour and instead toggle this menu
Gui.core_defines.show_top_flow:on_click(function(player, _, _)
    Gui.toggle_left_element(player, toolbar_container)
end)