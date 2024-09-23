--[[-- Core Module - Gui
- Gui defines that are used internally by the gui system
@module Gui
]]

local Gui = require 'expcore.gui.prototype'
local Event = require 'utils.event'

--- Core Defines.
-- @section coreDefines

--- Button which toggles the top flow elements, version which shows inside the top flow when top flow is visible
-- @element hide_top_flow
local hide_top_flow =
Gui.element{
    type = 'sprite-button',
    sprite = 'utility/preset',
    style = 'tool_button',
    tooltip = {'gui_util.button_tooltip'},
    name = Gui.unique_static_name
}
:style{
    padding = -2,
    width = 18,
    height = 36
}
:on_click(function(player, _,_)
    Gui.toggle_top_flow(player, false)
end)
Gui.core_defines.hide_top_flow = hide_top_flow

--- Button which toggles the top flow elements, version which shows inside the left flow when top flow is hidden
-- @element show_top_flow
local show_top_flow =
Gui.element{
    type = 'sprite-button',
    sprite = 'utility/preset',
    style = 'tool_button',
    tooltip = {'gui_util.button_tooltip'},
    name = Gui.unique_static_name
}
:style{
    padding = -2,
    width = 18,
    height = 20
}
:on_click(function(player, _,_)
    Gui.toggle_top_flow(player, true)
end)
Gui.core_defines.show_top_flow = show_top_flow

--- Button which hides the elements in the left flow, shows inside the left flow when frames are visible
-- @element hide_left_flow
local hide_left_flow =
Gui.element{
    type = 'sprite-button',
    sprite = 'utility/close_black',
    style = 'tool_button',
    tooltip = {'expcore-gui.left-button-tooltip'},
    name = Gui.unique_static_name
}
:style{
    padding = -3,
    width = 18,
    height = 20
}
:on_click(function(player, _,_)
    Gui.hide_left_flow(player)
end)
Gui.core_defines.hide_left_flow = hide_left_flow

--- Draw the core elements when a player joins the game
Event.add(defines.events.on_player_created, function(event)
    local player = game.players[event.player_index]

    -- Draw the top flow
    local top_flow = Gui.get_top_flow(player)
    hide_top_flow(top_flow)
    Gui.update_top_flow(player)

    -- Draw the left flow
    local left_flow = Gui.get_left_flow(player)
    local button_flow = left_flow.add{ type = 'flow', name = 'gui_core_buttons', direction = 'vertical' }
    local show_top = show_top_flow(button_flow)
    local hide_left = hide_left_flow(button_flow)
    show_top.visible = false
    hide_left.visible = false
    Gui.draw_left_flow(player)
end)