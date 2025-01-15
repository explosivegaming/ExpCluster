
--- @class ExpGui
local ExpGui = require("modules/exp_gui")
local mod_gui = require("mod-gui")

local toolbar_button_default_style = mod_gui.button_style
local toolbar_button_active_style = "menu_button_continue"
local toolbar_button_size = 36

local elements = {} --- @type table<string, ExpElement>
local buttons_with_left_element = {} --- @type table<string, ExpElement>
local left_elements_with_button = {} --- @type table<string, ExpElement>

ExpGui.on_toolbar_button_toggled = script.generate_event_name()

--- @class EventData.on_toolbar_button_toggled: EventData
--- @field element LuaGuiElement
--- @field state boolean

--- Set the style of a toolbar button
--- @param element LuaGuiElement
--- @param state boolean?
--- @return boolean
function ExpGui.set_toolbar_button_style(element, state)
    if state == nil then state = element.style.name == toolbar_button_default_style end
    element.style = state and toolbar_button_active_style or toolbar_button_default_style

    local style = element.style
    style.minimal_width = toolbar_button_size
    style.height = toolbar_button_size
    if element.type == "sprite-button" then
        style.padding = -2
    else
        style.font = "default-semibold"
        style.padding = 0
    end

    return state
end

--- Set the visible state of the top flow for a player
--- @param player LuaPlayer
--- @param state boolean?
function ExpGui.set_top_flow_visible(player, state)
    local top_flow = assert(ExpGui.get_top_flow(player).parent, player.name)
    local show_top_flow = elements.core_button_flow.data[player].show_top_flow --- @type LuaGuiElement

    if state == nil then
        state = not top_flow.visible
    end

    top_flow.visible = state
    show_top_flow.visible = not state
end

--- Set the visible state of the left element for a player
--- @param define ExpElement
--- @param player LuaPlayer
--- @param state boolean?
function ExpGui.set_left_element_visible(define, player, state)
    local element = assert(ExpGui.get_left_element(define, player), "Define is not added to the left flow")
    local clear_left_flow = elements.core_button_flow.data[player].clear_left_flow --- @type LuaGuiElement

    -- Update the visible state
    if state == nil then state = not element.visible end
    element.visible = state

    -- Check if there is a toolbar button linked to this element
    local toolbar_button = left_elements_with_button[define.name]
    if toolbar_button then
        ExpGui.set_toolbar_button_style(ExpGui.get_top_element(toolbar_button, player), state)
    end

    -- If visible state is true, then we don't need to check all elements
    if state then
        clear_left_flow.visible = true
        return
    end

    -- Check if any left elements are visible
    --- @diagnostic disable-next-line invisible
    local player_elements = ExpGui._get_player_elements(player)
    local flow_name = elements.core_button_flow.name
    for name, left_element in pairs(player_elements.left) do
        if left_element.visible and name ~= flow_name then
            clear_left_flow.visible = true
            return
        end
    end

    -- There are no visible left elements, so can hide the button
    clear_left_flow.visible = false
end

--- @class ExpGui.create_toolbar_button__param: LuaGuiElement.add_param.sprite_button, LuaGuiElement.add_param.button
--- @field name string
--- @field type nil
--- @field left_element ExpElement| nil
--- @field visible ExpGui.VisibleCallback | boolean | nil

--- Create a toolbar button
--- @param options ExpGui.create_toolbar_button__param
--- @return ExpElement
function ExpGui.create_toolbar_button(options)
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
        :draw(options)
        :style{
            minimal_width = toolbar_button_size,
            height = toolbar_button_size,
            padding = options.sprite ~= nil and -2 or nil,
        }

    -- If a left element was given then link the define
    if left_element then
        left_elements_with_button[left_element.name] = toolbar_button
        buttons_with_left_element[toolbar_button.name] = left_element
    end

    -- Setup auto toggle, required if there is a left element
    if auto_toggle or left_element then
        toolbar_button:on_click(function(def, event)
            local state = ExpGui.set_toolbar_button_style(event.element)
            if left_element then
                local player = ExpGui.get_player(event)
                ExpGui.set_left_element_visible(left_element, player, state)
            end
            script.raise_event(ExpGui.on_toolbar_button_toggled, {
                element = event.element,
                state = state,
            })
        end)
    end

    -- Add the define to the top flow and return
    ExpGui.add_top_element(toolbar_button, visible)
    return toolbar_button
end

--- Update the consistency of the core elements and registered elements
--- @param player LuaPlayer
--- @param skip_ensure boolean?
function ExpGui.apply_consistency_checks(player, skip_ensure)
    if not skip_ensure then
        --- @diagnostic disable-next-line invisible
        ExpGui._ensure_elements{ player_index = player.index }
    end

    -- Get the core buttons for the player
    local core_button_data = elements.core_button_flow.data[player]
    local hide_top_flow = ExpGui.get_top_element(elements.hide_top_flow, player)
    local show_top_flow = core_button_data.show_top_flow --- @type LuaGuiElement
    local clear_left_flow = core_button_data.clear_left_flow --- @type LuaGuiElement

    -- Check if any top elements are visible, this includes ones not controlled by this module
    local has_top_elements = false
    local top_flow = ExpGui.get_top_flow(player)
    for _, element in pairs(top_flow.children) do
        if element.visible and element ~= hide_top_flow then
            has_top_elements = true
            break
        end
    end

    -- The show button is only visible when the flow isn't visible but does have visible children
    show_top_flow.visible = has_top_elements and not top_flow.visible or false

    --- @diagnostic disable-next-line invisible
    local player_elements = ExpGui._get_player_elements(player)
    local left_elements, top_elements = player_elements.left, player_elements.top

    --- Update the styles of toolbar buttons with left elements
    for name, top_element in pairs(top_elements) do
        local left_element = buttons_with_left_element[name]
        if left_element then
            local element = assert(left_elements[left_element.name], left_element.name)
            ExpGui.set_toolbar_button_style(top_element, element.visible)
        end
    end

    -- Check if any left elements are visible
    local flow_name = elements.core_button_flow.name
    for name, left_element in pairs(left_elements) do
        if left_element.visible and name ~= flow_name then
            clear_left_flow.visible = true
            return
        end
    end

    -- There are no visible left elements, so can hide the button
    clear_left_flow.visible = false
end

--- Hides the top flow when clicked
elements.hide_top_flow = ExpGui.element("hide_top_flow")
    :draw{
        type = "sprite-button",
        sprite = "utility/preset",
        style = "tool_button",
        tooltip = { "exp-gui.hide-top-flow" },
    }
    :style{
        padding = -2,
        width = 18,
        height = 36,
    }
    :on_click(function(def, event)
        local player = ExpGui.get_player(event)
        ExpGui.set_top_flow_visible(player, false)
    end)

--- Shows the top flow when clicked
elements.show_top_flow = ExpGui.element("show_top_flow")
    :draw{
        type = "sprite-button",
        sprite = "utility/preset",
        style = "tool_button",
        tooltip = { "exp-gui.show-top-flow" },
    }
    :style{
        padding = -2,
        width = 18,
        height = 20,
    }
    :on_click(function(def, event)
        local player = ExpGui.get_player(event)
        ExpGui.set_top_flow_visible(player, true)
    end)

--- Hides all left elements when clicked
elements.clear_left_flow = ExpGui.element("clear_left_flow")
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
    :on_click(function(def, event)
        local player = ExpGui.get_player(event)
        event.element.visible = false

        --- @diagnostic disable-next-line invisible
        local player_elements = ExpGui._get_player_elements(player)
        local flow_name = elements.core_button_flow.name
        for name, left_element in pairs(player_elements.left) do
            if name ~= flow_name then
                left_element.visible = false
                local toolbar_button = left_elements_with_button[name]
                if toolbar_button then
                    ExpGui.set_toolbar_button_style(ExpGui.get_top_element(toolbar_button, player), false)
                end
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

        local player = ExpGui.get_player(parent)
        def.data[player] = {
            show_top_flow = elements.show_top_flow(flow),
            clear_left_flow = elements.clear_left_flow(flow),
        }

        return flow
    end)

ExpGui.add_top_element(elements.hide_top_flow, true)
ExpGui.add_left_element(elements.core_button_flow, true)

return elements
