--[[-- Core Module - Gui
- Used to simplify gui creation using factory functions called element defines
@core Gui
@alias Gui

@usage-- To draw your element you only need to call the factory function
-- You are able to pass any other arguments that are used in your custom functions but the first is always the parent element
local example_button_element = example_button(parent_element)

@usage-- Making a factory function for a button with the caption "Example Button"
-- This method has all the same features as LuaGuiElement.add
local example_button =
Gui.element{
    type = 'button',
    caption = 'Example Button'
}

@usage-- Making a factory function for a button which is contained within a flow
-- This method is for when you still want to register event handlers but cant use the table method
local example_flow_with_button =
Gui.element(function(definition, parent, ...)
    -- ... shows that all other arguments from the factory call are passed to this function
    -- Here we are adding a flow which we will then later add a button to
    local flow =
    parent.add{ -- paraent is the element which is passed to the factory function
        name = 'example_flow',
        type = 'flow'
    }

    -- Now we add the button to the flow that we created earlier
    local element = definition:triggers_event(
        flow.add{
            type = 'button',
            caption = 'Example Button'
        }
    )

    -- You must return a new element, this is so styles can be applied and returned to the caller
    -- You may return any of your elements that you added, consider the context in which it will be used for which should be returned
    return element
end)

@usage-- Styles can be added to any element define, simplest way mimics LuaGuiElement.style[key] = value
local example_button =
Gui.element{
    type = 'button',
    caption = 'Example Button',
    style = 'forward_button' -- factorio styles can be applied here
}
:style{
    height = 25, -- same as element.style.height = 25
    width = 100 -- same as element.style.width = 25
}

@usage-- Styles can also have a custom function when the style is dynamic and depends on other factors
-- Use this method if your style is dynamic and depends on other factors
local example_button =
Gui.element{
    type = 'button',
    caption = 'Example Button',
    style = 'forward_button' -- factorio styles can be applied here
}
:style(function(style, element, ...)
    -- style is the current style object for the elemenent
    -- element is the element that is being changed
    -- ... shows that all other arguments from the factory call are passed to this function
    local player = game.players[element.player_index]
    style.height = 25
    style.width = 100
    style.font_color = player.color
end)

@usage-- You are able to register event handlers to your elements, these can be factorio events or custom ones
-- All events are checked to be valid before raising any handlers, this means element.valid = true and player.valid = true
Gui.element{
    type = 'button',
    caption = 'Example Button'
}
:on_click(function(player, element, event)
    -- player is the player who interacted with the element to cause the event
    -- element is a refrence to the element which caused the event
    -- event is a raw refrence to the event data if player and element are not enough
    player.print('Clicked: '..element.name)
end)

@usage-- Example from core_defines, Gui.core_defines.hide_left_flow, called like: hide_left_flow(parent_element)
--- Button which hides the elements in the left flow, shows inside the left flow when frames are visible
-- @element hide_left_flow
local hide_left_flow =
Gui.element{
    type = 'sprite-button',
    sprite = 'utility/close_black',
    style = 'tool_button',
    tooltip = {'expcore-gui.left-button-tooltip'}
}
:style{
    padding = -3,
    width = 18,
    height = 20
}
:on_click(function(player, _,_)
    Gui.hide_left_flow(player)
end)

@usage-- Eample from defines, Gui.alignment, called like: Gui.alignment(parent, name, horizontal_align, vertical_align)
-- Notice how _ are used to blank arguments that are not needed in that context and how they line up with above
Gui.alignment =
Gui.element(function(_, parent, name, _,_)
    return parent.add{
        name = name or 'alignment',
        type = 'flow',
    }
end)
:style(function(style, _,_, horizontal_align, vertical_align)
    style.padding = {1, 2}
    style.vertical_align = vertical_align or 'center'
    style.horizontal_align = horizontal_align or 'right'
    style.vertically_stretchable  = style.vertical_align ~= 'center'
    style.horizontally_stretchable = style.horizontal_align ~= 'center'
end)

]]

local Gui = require 'expcore.gui.prototype'
require 'expcore.gui.helper_functions'
require 'expcore.gui.core_defines'
require 'expcore.gui.top_flow'
require 'expcore.gui.left_flow'
require 'expcore.gui.defines'

local Roles = _C.opt_require('expcore.roles')
local Event = _C.opt_require('utils.event')

if Roles and Event then
	Event.add(Roles.events.on_role_assigned, function(e)
		Gui.update_top_flow(game.get_player(e.player_index))
	end)
	Event.add(Roles.events.on_role_unassigned, function(e)
		Gui.update_top_flow(game.get_player(e.player_index))
	end)
end


return Gui