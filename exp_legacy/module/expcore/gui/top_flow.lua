--[[-- Core Module - Gui
- Controls the elements on the top flow
@module Gui
]]

local Gui = require 'expcore.gui.prototype'
local mod_gui = require 'mod-gui' --- @dep mod-gui

local toolbar_button_size = 36
local hide_top_flow = Gui.core_defines.hide_top_flow.name
local show_top_flow = Gui.core_defines.show_top_flow.name

--- Top Flow.
-- @section topFlow

-- Triggered when a user changed the visibility of a left flow element by clicking a button
Gui.events.on_toolbar_button_toggled = 'on_toolbar_button_toggled'

--- Contains the uids of the elements that will shown on the top flow and their auth functions
-- @table top_elements
Gui.top_elements = {}

--- The style that should be used for buttons on the top flow
-- @field Gui.top_flow_button_style
Gui.top_flow_button_style = mod_gui.button_style

--- The style that should be used for buttons on the top flow when their flow is visible
-- @field Gui.top_flow_button_toggled_style
Gui.top_flow_button_toggled_style = 'menu_button_continue'

--[[-- Styles a top flow button depending on the state given
@tparam LuaGuiElement button the button element to style
@tparam boolean state The state the button is in

@usage-- Sets the button to the visible style
Gui.toolbar_button_style(button, true)

@usage-- Sets the button to the hidden style
Gui.toolbar_button_style(button, false)

]]
function Gui.toolbar_button_style(button, state, size)
    ---@cast button LuaGuiElement
    if state then
        button.style = Gui.top_flow_button_toggled_style
    else
        button.style = Gui.top_flow_button_style
    end
    button.style.minimal_width = size or toolbar_button_size
    button.style.height = size or toolbar_button_size
    button.style.padding = -2
end

--[[-- Gets the flow refered to as the top flow, each player has one top flow
@function Gui.get_top_flow(player)
@tparam LuaPlayer player the player that you want to get the flow for
@treturn LuaGuiElement the top element flow

@usage-- Geting your top flow
local top_flow = Gui.get_top_flow(game.player)

]]
Gui.get_top_flow = mod_gui.get_button_flow

--[[-- Sets an element define to be drawn to the top flow when a player joins, includes optional authenticator
@tparam[opt] function authenticator called during toggle or update to decide weather the element should be visible
@treturn table the new element define to allow event handlers to be registered

@usage-- Adding an element to the top flow on join
example_button:add_to_top_flow(function(player)
    -- example button will only be shown if the player is an admin
    -- note button will not update its state when player.admin is changed Gui.update_top_flow must be called for this
    return player.admin
end)

]]
function Gui._prototype_element:add_to_top_flow(authenticator)
    _C.error_if_runtime()
    if not self.name then error("Elements for the top flow must have a static name") end
    self.authenticator = authenticator or true
    table.insert(Gui.top_elements, self)
    return self
end

--- Returns true if the top flow has visible elements
function Gui.top_flow_has_visible_elements(player)
    local top_flow = Gui.get_top_flow(player)

    for _, child in pairs(top_flow.children) do
        if child.name ~= hide_top_flow then
            if child.visible then
                return true
            end
        end
    end

    return false
end

Gui._top_flow_order_src = "<default>"
--- Get the order of elements in the top flow, first argument is player but is unused in the default method
function Gui.get_top_flow_order(_)
    return Gui.top_elements
end

--- Inject a custom top flow order provider, this should accept a player and return a list of elements definitions to draw
function Gui.inject_top_flow_order(provider)
    Gui.get_top_flow_order = provider
    local debug_info = debug.getinfo(2, "Sn")
    local file_name = debug_info.source:match('^.+/currently%-playing/(.+)$'):sub(1, -5)
    local func_name = debug_info.name or ("<anonymous:"..debug_info.linedefined..">")
    Gui._top_flow_order_src = file_name..":"..func_name
end

--[[-- Updates the visible state of all the elements on the players top flow, uses authenticator
@tparam LuaPlayer player the player that you want to update the top flow for

@usage-- Update your top flow
Gui.update_top_flow(game.player)

]]
function Gui.update_top_flow(player)
    local top_flow = Gui.get_top_flow(player)

    -- Get the order to draw the elements in
    local flow_order = Gui.get_top_flow_order(player)
    if #flow_order ~= #Gui.top_elements then
        error(string.format("Top flow order provider (%s) did not return the correct element count, expect %d got %d",
            Gui._top_flow_order_src, #Gui.top_elements, #flow_order
        ))
    end

    -- Set the visible state of all elements in the flow
    for index, element_define in ipairs(flow_order) do
        -- Ensure the element exists
        local element = top_flow[element_define.name]
        if not element then
            element = element_define(top_flow)
        else
            top_flow.swap_children(index+1, element.get_index_in_parent())
        end

        -- Set the visible state
        local allowed = element_define.authenticator
        if type(allowed) == 'function' then allowed = allowed(player) end
        element.visible = allowed or false

        -- If its not visible and there is a left element, then hide it
        if element_define.left_flow_element and not element.visible and Gui.left_flow_loaded(player, element_define.left_flow_element) then
            Gui.toggle_left_element(player, element_define.left_flow_element, false)
        end
    end

    -- Check if there are any visible elements in the top flow
    if not Gui.top_flow_has_visible_elements(player) then
        -- None are visible so hide the top_flow and its show button
        Gui.toggle_top_flow(player, false)
        local left_flow = Gui.get_left_flow(player)
        local show_button = left_flow.gui_core_buttons[show_top_flow]
        show_button.visible = false
    end
end

--- Reorder the top flow elements to match that returned by the provider, uses a method equivalent to insert sort
function Gui.reorder_top_flow(player)
    local top_flow = Gui.get_top_flow(player)

    -- Get the order to draw the elements in
    local flow_order = Gui.get_top_flow_order(player)
    if #flow_order ~= #Gui.top_elements then
        error(string.format("Top flow order provider (%s) did not return the correct element count, expect %d got %d",
            Gui._top_flow_order_src, #Gui.top_elements, #flow_order
        ))
    end

    -- Reorder the elements, index 1 is the core ui buttons so +1 is required
    for index, element_define in ipairs(flow_order) do
        local element = top_flow[element_define.name]
        top_flow.swap_children(index+1, element.get_index_in_parent())
    end
end

--[[-- Toggles the visible state of all the elements on a players top flow, effects all elements
@tparam LuaPlayer player the player that you want to toggle the top flow for
@tparam[opt] boolean state if given then the state will be set to this
@treturn boolean the new visible state of the top flow

@usage-- Toggle your flow
Gui.toggle_top_flow(game.player)

@usage-- Open your top flow
Gui.toggle_top_flow(game.player, true)

]]
function Gui.toggle_top_flow(player, state)
    -- Get the top flow, we need the parent as we want to toggle the outer frame
    local top_flow = Gui.get_top_flow(player).parent
    if state == nil then state = not top_flow.visible end

    -- Get the show button for the top flow
    local left_flow = Gui.get_left_flow(player)
    local show_button = left_flow.gui_core_buttons[show_top_flow]

    -- Change the visibility of the top flow and show top flow button
    show_button.visible = not state
    top_flow.visible = state

    return state
end

--[[-- Get the element define that is in the top flow, use in events without an element refrence
@tparam LuaPlayer player the player that you want to get the element for
@tparam table element_define the element that you want to get
@treturn LuaGuiElement the gui element linked to this define for this player

@usage-- Get your top element
local button = Gui.get_top_element(game.player, example_button)

]]
function Gui.get_top_element(player, element_define)
    local top_flow = Gui.get_top_flow(player)
    return assert(top_flow[element_define.name], "Top element failed to load")
end

--[[-- Toggles the state of a toolbar button for a given player, can be used to set the visual state
@tparam LuaPlayer player the player that you want to toggle the element for
@tparam table element_define the element that you want to toggle
@tparam[opt] boolean state with given will set the state, else state will be toggled
@treturn boolean the new visible state of the element

@usage-- Toggle your example button
Gui.toggle_toolbar_button(game.player, toolbar_button)

@usage-- Show your example button
Gui.toggle_toolbar_button(game.player, toolbar_button, true)

]]
function Gui.toggle_toolbar_button(player, element_define, state)
    local toolbar_button = Gui.get_top_element(player, element_define)
    if state == nil then state = toolbar_button.style.name ~= Gui.top_flow_button_toggled_style end
    Gui.toolbar_button_style(toolbar_button, state, toolbar_button.style.minimal_width)
    element_define:raise_event{
        name = Gui.events.on_toolbar_button_toggled,
        element = toolbar_button,
        player = player,
        state = state
    }
    return state
end

--[[-- Creates a button on the top flow with consistent styling
@tparam string sprite the sprite that you want to use on the button
@tparam ?string|Concepts.LocalizedString tooltip the tooltip that you want the button to have
@tparam[opt] function authenticator used to decide if the button should be visible to a player

@usage-- Add a button to the toolbar
local toolbar_button =
Gui.left_toolbar_button('entity/inserter', 'Nothing to see here', function(player)
    return player.admin
end)

]]
function Gui.toolbar_button(sprite, tooltip, authenticator)
    return Gui.element{
        type = 'sprite-button',
        sprite = sprite,
        tooltip = tooltip,
        style = Gui.top_flow_button_style,
        name = Gui.unique_static_name
    }
    :style{
        minimal_width = toolbar_button_size,
        height = toolbar_button_size,
        padding = -2
    }
    :add_to_top_flow(authenticator)
end

--[[-- Creates a toggle button on the top flow with consistent styling
@tparam string sprite the sprite that you want to use on the button
@tparam ?string|Concepts.LocalizedString tooltip the tooltip that you want the button to have
@tparam[opt] function authenticator used to decide if the button should be visible to a player

@usage-- Add a button to the toolbar
local toolbar_button =
Gui.toolbar_toggle_button('entity/inserter', 'Nothing to see here', function(player)
    return player.admin
end)
:on_event(Gui.events.on_toolbar_button_toggled, function(player, element, event)
    game.print(table.inspect(event))
end)

]]
function Gui.toolbar_toggle_button(sprite, tooltip, authenticator)
    local button =
    Gui.element{
        type = 'sprite-button',
        sprite = sprite,
        tooltip = tooltip,
        style = Gui.top_flow_button_style,
        name = Gui.unique_static_name
    }
    :style{
        minimal_width = toolbar_button_size,
        height = toolbar_button_size,
        padding = -2
    }
    :add_to_top_flow(authenticator)

    button:on_click(function(player, _, _)
        Gui.toggle_toolbar_button(player, button)
    end)

    return button
end