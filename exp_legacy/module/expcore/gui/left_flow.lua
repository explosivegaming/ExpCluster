--[[-- Core Module - Gui
- Used to define new gui elements and gui event handlers
@module Gui
]]

local Gui = require("modules.exp_legacy.expcore.gui.prototype")
local mod_gui = require "mod-gui"

local hide_left_flow = Gui.core_defines.hide_left_flow.name

--- Left Flow.
-- @section leftFlow

-- Triggered when a user changed the visibility of a left flow element by clicking a button
Gui.events.on_visibility_changed_by_click = "on_visibility_changed_by_click"

--- Contains the uids of the elements that will shown on the left flow and their join functions
-- @table left_elements
Gui.left_elements = {}

--[[-- Gets the flow refered to as the left flow, each player has one left flow
@function Gui.get_left_flow(player)
@tparam LuaPlayer player the player that you want to get the left flow for
@treturn LuaGuiElement the left element flow

@usage-- Geting your left flow
local left_flow = Gui.get_left_flow(game.player)

]]
Gui.get_left_flow = mod_gui.get_frame_flow

--[[-- Sets an element define to be drawn to the left flow when a player joins, includes optional check
@tparam[opt] ?boolean|function open_on_join called during first darw to decide if the element should be visible
@treturn table the new element define that is used to register events to this element

@usage-- Adding the example button
example_flow_with_button:add_to_left_flow(true)

]]
function Gui._prototype_element:add_to_left_flow(open_on_join)
    _C.error_if_runtime()
    if not self.name then error("Elements for the top flow must have a static name") end
    self.open_on_join = open_on_join or false
    table.insert(Gui.left_elements, self)
    return self
end

--[[-- Creates a button on the top flow which will toggle the given element define, the define must exist in the left flow
@tparam string sprite the sprite that you want to use on the button
@tparam ?string|Concepts.LocalizedString tooltip the tooltip that you want the button to have
@tparam table element_define the element define that you want to have toggled by this button, define must exist on the left flow
@tparam[opt] function authenticator used to decide if the button should be visible to a player

@usage-- Add a button to toggle a left element
local toolbar_button =
Gui.left_toolbar_button('entity/inserter', 'Nothing to see here', example_flow_with_button, function(player)
    return player.admin
end)

]]
function Gui.left_toolbar_button(sprite, tooltip, element_define, authenticator)
    local button = Gui.toolbar_button(sprite, tooltip, authenticator)

    -- Add on_click handler to handle click events comming from the player
    button:on_click(function(player, _, _)
        -- Raise custom event that tells listening elements if the element has changed visibility by a player clicking
        -- Used in warp gui to handle the keep open logic
        button:raise_event{
            name = Gui.events.on_visibility_changed_by_click,
            element = Gui.get_top_element(player, button),
            state = Gui.toggle_left_element(player, element_define),
        }
    end)

    -- Add property to the left flow element with the name of the button
    -- This is for the ability to reverse lookup the button from the left flow element
    element_define.toolbar_button = button
    button.left_flow_element = element_define
    return button
end

Gui._left_flow_order_src = "<default>"
--- Get the order of elements in the left flow, first argument is player but is unused in the default method
function Gui.get_left_flow_order(_)
    return Gui.left_elements
end

--- Inject a custom left flow order provider, this should accept a player and return a list of elements definitions to draw
function Gui.inject_left_flow_order(provider)
    Gui.get_left_flow_order = provider
    local debug_info = debug.getinfo(2, "Sn")
    local file_name = debug_info.short_src:sub(10, -5)
    local func_name = debug_info.name or ("<anonymous:" .. debug_info.linedefined .. ">")
    Gui._left_flow_order_src = file_name .. ":" .. func_name
end

--[[-- Draw all the left elements onto the left flow, internal use only with on join
@tparam LuaPlayer player the player that you want to draw the elements for

@usage-- Draw all the left elements
Gui.draw_left_flow(player)

]]
function Gui.draw_left_flow(player)
    local left_flow = Gui.get_left_flow(player)
    local hide_button = left_flow.gui_core_buttons[hide_left_flow]
    local show_hide_button = false

    -- Get the order to draw the elements in
    local flow_order = Gui.get_left_flow_order(player)
    if #flow_order ~= #Gui.left_elements then
        error(string.format("Left flow order provider (%s) did not return the correct element count, expect %d got %d",
            Gui._left_flow_order_src, #Gui.left_elements, #flow_order
        ))
    end

    for _, element_define in ipairs(flow_order) do
        -- Draw the element to the left flow
        local draw_success, left_element = xpcall(function()
            return element_define(left_flow)
        end, debug.traceback)

        if not draw_success then
            log("There as been an error with an element draw function: " .. element_define.defined_at .. "\n\t" .. left_element)
            goto continue
        end

        -- Check if it should be open by default
        local open_on_join = element_define.open_on_join
        local visible = type(open_on_join) == "boolean" and open_on_join or false
        if type(open_on_join) == "function" then
            local success, err = xpcall(open_on_join, debug.traceback, player)
            if not success then
                log("There as been an error with an open on join hander for a gui element:\n\t" .. err)
                goto continue
            end
            visible = err
        end

        -- Set the visible state of the element
        left_element.visible = visible
        show_hide_button = show_hide_button or visible

        -- Check if the the element has a button attached
        if element_define.toolbar_button then
            Gui.toggle_toolbar_button(player, element_define.toolbar_button, visible)
        end
        ::continue::
    end

    hide_button.visible = show_hide_button
end

--- Reorder the left flow elements to match that returned by the provider, uses a method equivalent to insert sort
function Gui.reorder_left_flow(player)
    local left_flow = Gui.get_left_flow(player)

    -- Get the order to draw the elements in
    local flow_order = Gui.get_left_flow_order(player)
    if #flow_order ~= #Gui.left_elements then
        error(string.format("Left flow order provider (%s) did not return the correct element count, expect %d got %d",
            Gui._left_flow_order_src, #Gui.left_elements, #flow_order
        ))
    end

    -- Reorder the elements, index 1 is the core ui buttons so +1 is required
    for index, element_define in ipairs(flow_order) do
        local element = left_flow[element_define.name]
        left_flow.swap_children(index + 1, element.get_index_in_parent())
    end
end

--[[-- Update the visible state of the hide button, can be used to check if any frames are visible
@tparam LuaPlayer player the player to update the left flow for
@treturn boolean true if any left element is visible

@usage-- Check if any left elements are visible
local visible = Gui.update_left_flow(player)

]]
function Gui.update_left_flow(player)
    local left_flow = Gui.get_left_flow(player)
    local hide_button = left_flow.gui_core_buttons[hide_left_flow]
    for _, element_define in ipairs(Gui.left_elements) do
        local left_element = left_flow[element_define.name]
        if left_element.visible then
            hide_button.visible = true
            return true
        end
    end

    hide_button.visible = false
    return false
end

--[[-- Hides all left elements for a player
@tparam LuaPlayer player the player to hide the elements for

@usage-- Hide your left elements
Gui.hide_left_flow(game.player)

]]
function Gui.hide_left_flow(player)
    local top_flow = Gui.get_top_flow(player)
    local left_flow = Gui.get_left_flow(player)
    local hide_button = left_flow.gui_core_buttons[hide_left_flow]

    -- Set the visible state of all elements in the flow
    hide_button.visible = false
    for _, element_define in ipairs(Gui.left_elements) do
        left_flow[element_define.name].visible = false

        -- Check if the the element has a toobar button attached
        if element_define.toolbar_button then
            -- Check if the topflow contains the button
            local button = top_flow[element_define.toolbar_button.name]
            if button then
                -- Style the button
                Gui.toggle_toolbar_button(player, element_define.toolbar_button, false)
                -- Raise the custom event if all of the top checks have passed
                element_define.toolbar_button:raise_event{
                    name = Gui.events.on_visibility_changed_by_click,
                    element = button,
                    state = false,
                }
            end
        end
    end
end

--- Checks if an element is loaded, used internally when the normal left gui assumptions may not hold
function Gui.left_flow_loaded(player, element_define)
    local left_flow = Gui.get_left_flow(player)
    return left_flow[element_define.name] ~= nil
end

--[[-- Get the element define that is in the left flow, use in events without an element refrence
@tparam LuaPlayer player the player that you want to get the element for
@tparam table element_define the element that you want to get
@treturn LuaGuiElement the gui element linked to this define for this player

@usage-- Get your left element
local frame = Gui.get_left_element(game.player, example_flow_with_button)

]]
function Gui.get_left_element(player, element_define)
    local left_flow = Gui.get_left_flow(player)
    return assert(left_flow[element_define.name], "Left element failed to load")
end

--[[-- Toggles the visible state of a left element for a given player, can be used to set the visible state
@tparam LuaPlayer player the player that you want to toggle the element for
@tparam table element_define the element that you want to toggle
@tparam[opt] boolean state with given will set the state, else state will be toggled
@treturn boolean the new visible state of the element

@usage-- Toggle your example button
Gui.toggle_top_flow(game.player, example_flow_with_button)

@usage-- Show your example button
Gui.toggle_top_flow(game.player, example_flow_with_button, true)

]]
function Gui.toggle_left_element(player, element_define, state)
    -- Set the visible state
    local element = Gui.get_left_element(player, element_define)
    if state == nil then state = not element.visible end
    element.visible = state
    Gui.update_left_flow(player)

    -- Check if the the element has a button attached
    if element_define.toolbar_button then
        Gui.toggle_toolbar_button(player, element_define.toolbar_button, state)
    end
    return state
end
