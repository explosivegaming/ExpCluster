
--- @class ExpGui
local ExpGui = require("modules/exp_gui")
local ExpElement = require("modules/exp_gui/prototype")
local mod_gui = require("mod-gui")

local toolbar_button_default_style = mod_gui.button_style
local toolbar_button_active_style = "menu_button_continue"
local toolbar_button_size = 36
local toolbar_button_small = 20

--- @class ExpGui.toolbar
local Toolbar = {}
ExpGui.toolbar = Toolbar

local elements = {}
Toolbar.elements = elements

local toolbar_buttons = {} --- @type ExpElement[]
local left_elements_with_button = {} --- @type table<ExpElement, ExpElement>
local buttons_with_left_element = {} --- @type table<string, ExpElement>

--- Set the visible state of the toolbar
--- @param player LuaPlayer
--- @param state boolean? toggles if nil
--- @return boolean
function Toolbar.set_visible_state(player, state)
    -- Update the top flow
    local top_flow = assert(ExpGui.get_top_flow(player).parent)
    if state == nil then state = not top_flow.visible end
    top_flow.visible = state

    -- Update the open toolbar button
    for _, open_toolbar in elements.open_toolbar:tracked_elements(player) do
        open_toolbar.visible = not state
    end

    -- Update the toggle toolbar button
    for _, toggle_toolbar in elements.toggle_toolbar:tracked_elements(player) do
        toggle_toolbar.toggled = state
    end

    return state
end

--- Get the visible state of the toolbar
--- @param player LuaPlayer
--- @return boolean
function Toolbar.get_visible_state(player)
    local top_flow = assert(ExpGui.get_top_flow(player).parent)
    return top_flow.visible
end

--- Set the toggle state of a toolbar button, does not check for a linked left element
--- @param define ExpElement
--- @param player LuaPlayer
--- @param state boolean? toggles if nil
--- @return boolean
function Toolbar.set_button_toggled_state(define, player, state)
    local top_element = assert(ExpGui.get_top_element(define, player), "Element is not on the top flow")
    if state == nil then state = top_element.style.name == toolbar_button_default_style end

    for _, element in define:tracked_elements(player) do
        local original_width, original_height = element.style.minimal_width, element.style.maximal_height
        element.style = state and toolbar_button_active_style or toolbar_button_default_style

        -- Make the extra required adjustments
        local style = element.style
        style.minimal_width = original_width
        style.maximal_height = original_height
        if element.type == "sprite-button" then
            style.padding = -2
        else
            style.font = "default-semibold"
            style.padding = 0
        end
    end

    return state
end

--- Get the toggle state of a toolbar button
--- @param define ExpElement
--- @param player LuaPlayer
--- @return boolean
function Toolbar.get_button_toggled_state(define, player)
    local element = assert(ExpGui.get_top_element(define, player), "Element is not on the top flow")
    return element.style.name == toolbar_button_active_style
end

--- Set the visible state of a left element
--- @param define ExpElement
--- @param player LuaPlayer
--- @param state boolean? toggles if nil
--- @param _skip_consistency boolean?
--- @return boolean
function Toolbar.set_left_element_visible_state(define, player, state, _skip_consistency)
    local element = assert(ExpGui.get_left_element(define, player), "Element is not on the left flow")
    if state == nil then state = not element.visible end
    element.visible = state

    -- Check if there is a linked toolbar button and update it
    local button = left_elements_with_button[define]
    if button then
        Toolbar.set_button_toggled_state(button, player, state)
    end

    -- This check is O(n^2) when setting all left elements to hidden, so internals can it
    if _skip_consistency then return state end

    -- Update the clear left flow button, visible when at least one element is visible
    local has_visible = Toolbar.has_visible_left_elements(player)
    for _, clear_left_flow in elements.clear_left_flow:tracked_elements(player) do
        clear_left_flow.visible = state or has_visible
    end

    return state
end

--- Get the toggle state of a left element
--- @param define ExpElement
--- @param player LuaPlayer
--- @return boolean
function Toolbar.get_left_element_visible_state(define, player)
    local element = assert(ExpGui.get_left_element(define, player), "Element is not on the left flow")
    return element.visible
end

--- Check if there are any visible toolbar buttons
--- @param player any
--- @return boolean
function Toolbar.has_visible_buttons(player)
    local top_flow = ExpGui.get_top_flow(player)
    local settings_button = ExpGui.get_top_element(elements.close_toolbar, player)

    for _, element in pairs(top_flow.children) do
        if element.visible and element ~= settings_button then
            return true
        end
    end

    return false
end

--- Check if there are any visible left elements
--- @param player any
--- @return boolean
function Toolbar.has_visible_left_elements(player)
    local left_flow = ExpGui.get_left_flow(player)
    local core_button_flow = ExpGui.get_left_element(elements.core_button_flow, player)

    for _, element in pairs(left_flow.children) do
        if element.visible and element ~= core_button_flow then
            return true
        end
    end

    return false
end

--- @class ExpGui.toolbar.create_button__param: LuaGuiElement.add_param.sprite_button, LuaGuiElement.add_param.button
--- @field name string
--- @field type nil
--- @field left_element ExpElement| nil
--- @field visible ExpGui.VisibleCallback | boolean | nil

--- Create a toolbar button
--- @param options ExpGui.toolbar.create_button__param
--- @return ExpElement
function Toolbar.create_button(options)
    -- Extract the custom options from the element.add options
    local name = assert(options.name, "Name is required for the element")
    options.type = options.sprite ~= nil and "sprite-button" or "button"

    local visible = options.visible
    if visible == nil then visible = true end
    options.visible = nil

    local auto_toggle = options.auto_toggle
    options.auto_toggle = nil

    local left_element = options.left_element
    options.left_element = nil

    if options.style == nil then
        options.style = toolbar_button_default_style
    end

    -- Create the new element define
    local toolbar_button = ExpGui.element(name)
        :track_all_elements()
        :draw(options)
        :style{
            minimal_width = toolbar_button_size,
            height = toolbar_button_size,
            padding = options.sprite ~= nil and -2 or nil,
        }

    -- If a left element was given then link the define
    if left_element then
        left_elements_with_button[left_element] = toolbar_button
        buttons_with_left_element[toolbar_button.name] = left_element
    end

    -- Setup auto toggle, required if there is a left element
    if auto_toggle or left_element then
        toolbar_button:on_click(function(def, player)
            if left_element then
                Toolbar.set_left_element_visible_state(left_element, player)
            else
                Toolbar.set_button_toggled_state(toolbar_button, player)
            end
        end)
    end

    -- Add the define to the top flow and return
    toolbar_buttons[#toolbar_buttons + 1] = toolbar_button
    ExpGui.add_top_element(toolbar_button, visible)
    return toolbar_button
end

--- Toggles the toolbar settings, RMB will instead hide the toolbar
elements.close_toolbar = ExpGui.element("close_toolbar")
    :draw{
        type = "sprite-button",
        sprite = "utility/preset",
        style = "tool_button",
        tooltip = { "exp-gui.close-toolbar" },
    }
    :style{
        padding = -2,
        width = 18,
        height = 36,
    }
    :on_click(function(def, player, element, event)
        if event.button == defines.mouse_button_type.left then
            Toolbar.set_left_element_visible_state(elements.toolbar_settings, player)
        else
            Toolbar.set_visible_state(player, false)
        end
    end)

--- Shows the toolbar, if no buttons are visible then it shows the settings instead
elements.open_toolbar = ExpGui.element("open_toolbar")
    :track_all_elements()
    :draw{
        type = "sprite-button",
        sprite = "utility/preset",
        style = "tool_button",
        tooltip = { "exp-gui.open-toolbar" },
    }
    :style{
        padding = -2,
        width = 18,
        height = 20,
    }
    :on_click(function(def, player, element, event)
        if event.button == defines.mouse_button_type.left then
            Toolbar.set_left_element_visible_state(elements.toolbar_settings, player)
        else
            Toolbar.set_visible_state(player, true)
        end
    end)

--- Hides all left elements when clicked
elements.clear_left_flow = ExpGui.element("clear_left_flow")
    :track_all_elements()
    :draw{
        type = "sprite-button",
        sprite = "utility/close_black",
        style = "tool_button",
        tooltip = { "exp-gui.clear-left-flow" },
    }
    :style{
        padding = -3,
        width = 18,
        height = 20,
    }
    :on_click(function(def, player, element)
        element.visible = false
        for define in pairs(ExpGui.left_elements) do
            if define ~= elements.core_button_flow then
                Toolbar.set_left_element_visible_state(define, player, false, true)
            end
        end
    end)

--- Contains the two buttons on the left flow
elements.core_button_flow = ExpGui.element("core_button_flow")
    :draw(function(def, parent)
        local flow = parent.add{
            type = "flow",
            direction = "vertical",
        }

        elements.open_toolbar(flow)
        elements.clear_left_flow(flow)

        return flow
    end)

--[[
Below here is the toolbar settings GUI and its associated functions
]]

--- Set the style of the fake toolbar element
--- @param src LuaGuiElement
--- @param dst LuaGuiElement
local function copy_style(src, dst)
    dst.style = src.style.name
    dst.style.height = toolbar_button_small
    dst.style.width = toolbar_button_small
    dst.style.padding = -2
end

--- Reorder the buttons relative to each other, this will update the datastore
--- @param player LuaPlayer
--- @param item LuaGuiElement
--- @param offset number
local function move_toolbar_button(player, item, offset)
    local old_index = item.get_index_in_parent()
    local new_index = old_index + offset

    -- Swap the position in the list
    local list = assert(item.parent)
    local other_item = list.children[new_index]
    list.swap_children(old_index, new_index)

    -- Swap the position in the top flow, offset by 1 because of settings button
    local top_flow = ExpGui.get_top_flow(player)
    top_flow.swap_children(old_index + 1, new_index + 1)

    -- Check if the element has a left element to move
    local left_element = buttons_with_left_element[item.name]
    local other_left_element = buttons_with_left_element[other_item.name]
    if left_element and other_left_element then
        local element = ExpGui.get_left_element(left_element, player)
        local other_element = ExpGui.get_left_element(other_left_element, player)
        local left_index = element.get_index_in_parent()
        local other_index = other_element.get_index_in_parent()
        element.parent.swap_children(left_index, other_index)
    end

    -- If we are moving in/out of first/last place we need to update the move buttons
    local last_index = #list.children
    local item_data = elements.toolbar_list_item.data[item]
    local other_item_data = elements.toolbar_list_item.data[other_item]
    if old_index == 1 then -- Moving out of index 1
        item_data.move_item_up.enabled = true
        other_item_data.move_item_up.enabled = false
    elseif new_index == 1 then -- Moving into index 1
        item_data.move_item_up.enabled = false
        other_item_data.move_item_up.enabled = true
    elseif old_index == last_index then -- Moving out of the last index
        item_data.move_item_down.enabled = true
        other_item_data.move_item_down.enabled = false
    elseif new_index == last_index then -- Moving into the last index
        item_data.move_item_down.enabled = false
        other_item_data.move_item_down.enabled = true
    end
end

--- @alias ExpGui.ToolbarOrder { name: string, favourite: boolean }[]

--- Reorder the toolbar buttons
--- @param player LuaPlayer
--- @param order ExpGui.ToolbarOrder
function Toolbar.set_order(player, order)
    local list = elements.toolbar_settings.data[player] --[[ @as LuaGuiElement ]]
    local left_flow = ExpGui.get_left_flow(player)
    local top_flow = ExpGui.get_top_flow(player)

    -- Reorder the buttons
    local left_index = 1
    local last_index = #order
    for index, item_state in ipairs(order) do
        -- Switch item order
        local item = assert(list[item_state.name], "Missing toolbox item for " .. tostring(item_state.name))
        list.swap_children(index, item.get_index_in_parent())

        -- Switch the toolbar button order
        local element_define = ExpElement.get(item_state.name)
        local toolbar_button = ExpGui.get_top_element(element_define, player)
        top_flow.swap_children(index + 1, toolbar_button.get_index_in_parent())

        -- Update the children buttons
        local data = elements.toolbar_list_item.data[item]
        data.set_favourite.state = item_state.favourite
        data.move_item_up.enabled = index ~= 1
        data.move_item_down.enabled = index ~= last_index

        -- Switch the left element order
        local left_define = buttons_with_left_element[item_state.name]
        if left_define then
            local left_element = ExpGui.get_left_element(left_define, player)
            left_flow.swap_children(left_index, left_element.get_index_in_parent())
            left_index = left_index + 1
        end
    end
end

--- @class (exact) ExpGui.ToolbarState 
--- @field order ExpGui.ToolbarOrder
--- @field open string[]
--- @field visible boolean

--- Reorder the toolbar buttons and set the open state of the left flows
--- @param player LuaPlayer
--- @param state ExpGui.ToolbarState
function Toolbar.set_state(player, state)
    Toolbar.set_order(player, state.order)
    Toolbar.set_visible_state(player, state.visible)

    local done = {}
    -- Make all open elements visible
    for _, name in pairs(state.open) do
        local left_element = ExpElement.get(name)
        Toolbar.set_left_element_visible_state(left_element, player, true, true)
        done[left_element] = true
    end

    -- Make all other elements hidden
    for left_element in pairs(ExpGui.left_elements) do
        if not done[left_element] then
            Toolbar.set_left_element_visible_state(left_element, player, false, true)
        end
    end

    -- Update clear_left_flow (because we skip above)
    local has_visible = Toolbar.has_visible_left_elements(player)
    for _, clear_left_flow in elements.clear_left_flow:tracked_elements(player) do
        clear_left_flow.visible = has_visible
    end
end

--- Get the full toolbar state for a player
--- @param player LuaPlayer
--- @return ExpGui.ToolbarState
function Toolbar.get_state(player)
    -- Get the order of toolbar buttons
    local order = {}
    local list = elements.toolbar_settings.data[player] --[[ @as LuaGuiElement ]]
    for index, item in pairs(list.children) do
        order[index] = { name = item.name, favourite = elements.toolbar_list_item.data[item].set_favourite.state }
    end

    -- Get the names of all open left elements
    local open, open_index = {}, 1
    for left_element in pairs(ExpGui.left_elements) do
        if Toolbar.get_left_element_visible_state(left_element, player) then
            open[open_index] = left_element.name
            open_index = open_index + 1
        end
    end

    return { order = order, open = open, visible = Toolbar.get_visible_state(player) }
end

--- Ensure the toolbar settings gui has all its elements
--- @param player LuaPlayer
function Toolbar._create_elements(player)
    -- Add any missing items to the gui
    local toolbar_list = elements.toolbar_settings.data[player] --[[ @as LuaGuiElement ]]
    local previous_last_index = #toolbar_list.children_names
    for define in pairs(ExpGui.top_elements) do
        if define ~= elements.close_toolbar and toolbar_list[define.name] == nil then
            local element = elements.toolbar_list_item(toolbar_list, define)
            element.visible = ExpGui.get_top_element(define, player).visible
        end
    end

    -- Reset the state of the previous last child
    local children = toolbar_list.children
    if previous_last_index > 0 then
        elements.toolbar_list_item.data[children[previous_last_index]].move_item_down.enabled = true
    end

    -- Set the state of the move buttons for the first and last element
    if #children > 0 then
        elements.toolbar_list_item.data[children[1]].move_item_up.enabled = false
        elements.toolbar_list_item.data[children[#children]].move_item_down.enabled = false
    end
end

--- Ensure all the toolbar buttons are in a consistent state
--- @param player LuaPlayer
function Toolbar._ensure_consistency(player)
    -- Update the toolbar buttons
    local list = elements.toolbar_settings.data[player] --[[ @as LuaGuiElement ]]
    for _, button in ipairs(toolbar_buttons) do
        -- Update the visible state based on if the player is allowed the button
        local element = ExpGui.get_top_element(button, player)
        local allowed = ExpGui.top_elements[button]
        if type(allowed) == "function" then
            allowed = allowed(player, element)
        end
        element.visible = allowed and element.visible or false
        list[button.name].visible = element.visible

        -- Update the toggle state and hide the linked left element if the button is not allowed
        local left_define = buttons_with_left_element[button.name]
        if left_define then
            local left_element = ExpGui.get_left_element(left_define, player)
            Toolbar.set_button_toggled_state(button, player, left_element.visible)
            if not allowed then
                Toolbar.set_left_element_visible_state(left_define, player, false)
            end
        end
    end

    -- Update clear_left_flow
    local has_visible = Toolbar.has_visible_left_elements(player)
    for _, clear_left_flow in elements.clear_left_flow:tracked_elements(player) do
        clear_left_flow.visible = has_visible
    end

    -- Update open_toolbar
    local top_flow = assert(ExpGui.get_top_flow(player).parent)
    for _, open_toolbar in elements.open_toolbar:tracked_elements(player) do
        open_toolbar.visible = not top_flow.visible
    end

    -- Update toggle_toolbar
    local has_buttons = Toolbar.has_visible_buttons(player)
    for _, toggle_toolbar in elements.toggle_toolbar:tracked_elements(player) do
        toggle_toolbar.enabled = has_buttons
    end
end

do
    local default_order --- @type ExpGui.ToolbarOrder
    --- Gets the default order for the toolbar
    --- @return ExpGui.ToolbarOrder
    function Toolbar.get_default_order()
        if default_order then return default_order end

        local index = 1
        default_order = {}
        for define in pairs(ExpGui.top_elements) do
            if define ~= elements.close_toolbar then
                default_order[index] = { name = define.name, favourite = true }
                index = index + 1
            end
        end

        return default_order
    end
end

--- Toggle the visibility of the toolbar, does not care if buttons are visible
elements.toggle_toolbar = ExpGui.element("toggle_toolbar")
    :track_all_elements()
    :draw{
        type = "sprite-button",
        sprite = "utility/bookmark",
        tooltip = { "exp-gui_toolbar-settings.toggle" },
        style = "tool_button",
        auto_toggle = true,
    }
    :style(ExpGui.styles.sprite{
        size = 22,
    })
    :on_click(function(def, player, element)
        Toolbar.set_visible_state(player, element.toggled)
    end)

--- Reset the toolbar to its default state
elements.reset_toolbar = ExpGui.element("reset_toolbar")
    :draw{
        type = "sprite-button",
        sprite = "utility/reset",
        style = "shortcut_bar_button_red",
        tooltip = { "exp-gui_toolbar-settings.reset" },
    }
    :style(ExpGui.styles.sprite{
        size = 22,
        padding = -1,
    })
    :on_click(function(def, player, element)
        Toolbar.set_order(player, Toolbar.get_default_order())
    end)

--- Move an item up/left on the toolbar
elements.move_item_up = ExpGui.element("move_item_up")
    :draw{
        type = "sprite-button",
        sprite = "utility/speed_up",
        tooltip = { "exp-gui_toolbar-settings.move-up" },
    }
    :style(ExpGui.styles.sprite{
        size = toolbar_button_small,
    })
    :on_click(function(def, player, element)
        local item = assert(element.parent.parent)
        move_toolbar_button(player, item, -1)
    end)

--- Move an item down/right on the toolbar
elements.move_item_down = ExpGui.element("move_item_down")
    :draw{
        type = "sprite-button",
        sprite = "utility/speed_down",
        tooltip = { "exp-gui_toolbar-settings.move-down" },
    }
    :style(ExpGui.styles.sprite{
        size = toolbar_button_small,
    })
    :on_click(function(def, player, element)
        local item = assert(element.parent.parent)
        move_toolbar_button(player, item, 1)
    end)

--- Set an item as a favourite, making it appear on the toolbar
elements.set_favourite = ExpGui.element("set_favourite")
    :draw(function(def, parent, item_define)
        --- @cast item_define ExpElement
        local player = ExpGui.get_player(parent)
        local top_element = ExpGui.get_top_element(item_define, player)

        return parent.add{
            type = "checkbox",
            caption = top_element.tooltip or top_element.caption or nil,
            state = top_element.visible or false,
            tags = {
                element_name = item_define.name,
            },
        }
    end)
    :style{
        width = 180,
    }
    :on_checked_state_changed(function(def, player, element)
        local define = ExpElement.get(element.tags.element_name --[[ @as string ]])
        local top_element = ExpGui.get_top_element(define, player)
        local had_visible = Toolbar.has_visible_buttons(player)
        top_element.visible = element.state

        -- Check if we are on the edge case between 0 and 1 visible elements
        if element.state and not had_visible then
            Toolbar.set_visible_state(player, true)
            for _, toggle_toolbar in elements.toggle_toolbar:tracked_elements(player) do
                toggle_toolbar.enabled = true
            end
        elseif not element.state and not Toolbar.has_visible_buttons(player) then
            Toolbar.set_visible_state(player, false)
            for _, toggle_toolbar in elements.toggle_toolbar:tracked_elements(player) do
                toggle_toolbar.enabled = false
            end
        end
    end)

elements.toolbar_list_item = ExpGui.element("toolbar_list_item")
    :draw(function(def, parent, item_define)
        --- @cast item_define ExpElement
        local data = {}

        -- Add the flow for the item
        local flow = parent.add{
            name = item_define.name,
            type = "frame",
            style = "shortcut_selection_row",
        }
        flow.style.horizontally_stretchable = true
        flow.style.vertical_align = "center"

        -- Add the button and the icon edit button
        local element = item_define(flow)
        local player = ExpGui.get_player(parent)
        local top_element = ExpGui.get_top_element(item_define, player)
        copy_style(top_element, element)

        -- Add the favourite checkbox and label
        data.set_favourite = elements.set_favourite(flow, item_define)

        -- Add the buttons used to move the flow up and down
        local move_flow = flow.add{ type = "flow", name = "move" }
        move_flow.style.horizontal_spacing = 0
        data.move_item_up = elements.move_item_up(move_flow)
        data.move_item_down = elements.move_item_down(move_flow)

        def.data[flow] = data
        return flow
    end)

--- Main list for all toolbar items
elements.toolbar_list = ExpGui.element("toolbar_list")
    :draw(function(def, parent)
        local scroll = parent.add{
            type = "scroll-pane",
            direction = "vertical",
            horizontal_scroll_policy = "never",
            vertical_scroll_policy = "auto",
            style = "scroll_pane_under_subheader",
        }
        scroll.style.horizontally_stretchable = true
        scroll.style.maximal_height = 224
        scroll.style.padding = 0

        -- This is required because vertical_spacing can't be set on a scroll pane
        return scroll.add{
            type = "flow",
            direction = "vertical",
        }
    end)
    :style{
        horizontally_stretchable = true,
        vertical_spacing = 0,
    }

-- The main container for the toolbar settings
elements.toolbar_settings = ExpGui.element("toolbar_settings")
    :draw(function(def, parent)
        -- Draw the container
        local frame = ExpGui.elements.container(parent, 268)
        frame.style.maximal_width = 268
        frame.style.minimal_width = 268

        -- Draw the header
        local player = ExpGui.get_player(parent)
        local header = ExpGui.elements.header(frame, {
            caption = { "exp-gui_toolbar-settings.main-caption" },
            tooltip = { "exp-gui_toolbar-settings.main-tooltip" },
        })

        -- Draw the toolbar control buttons
        local toggle_element = elements.toggle_toolbar(header)
        toggle_element.toggled = Toolbar.get_visible_state(player)
        elements.reset_toolbar(header)

        def.data[player] = elements.toolbar_list(frame)
        Toolbar._create_elements(player)
        return frame.parent
    end)

ExpGui.add_left_element(elements.core_button_flow, true)
ExpGui.add_left_element(elements.toolbar_settings, false)
ExpGui.add_top_element(elements.close_toolbar, true)

return Toolbar
