--[[-- Core Module - Gui
- Used to simplify gui creation using factory functions called element defines
@module Gui
]]

local Event = require 'utils.event' --- @dep utils.event

local Gui = {
    --- The current highest uid that is being used by a define, will not increase during runtime
    uid = 0,
    --- Used to automatically assign a unique static name to an element
    unique_static_name = {},
    --- String indexed table used to avoid conflict with custom event names, similar to how defines.events works
    events = {},
    --- Uid indexed array that stores all the factory functions that were defined, no new values will be added during runtime
    defines = {},
    --- An string indexed table of all the defines which are used by the core of the gui system, used for internal reference
    core_defines = {},
    --- Used to store the file names where elements were defined, this can be useful to find the uid of an element, mostly for debugging
    file_paths = {},
    --- Used to store extra information about elements as they get defined such as the params used and event handlers registered to them
    debug_info = {},
    --- The prototype used to store the functions of an element define
    _prototype_element = {},
    --- The prototype metatable applied to new element defines
    _mt_element = {}
}

--- Allow access to the element prototype methods
Gui._mt_element.__index = Gui._prototype_element

--- Allows the define to be called to draw the element
function Gui._mt_element.__call(self, parent, ...)
    local element, no_events = self._draw(self, parent, ...)
    if self._style then self._style(element.style, element, ...) end

    -- Asserts to catch common errors
    if element then
        if self.name and self.name ~= element.name then
            error("Static name \""..self.name.."\" expected but got: "..tostring(element.name))
        end
        local event_triggers = element.tags and element.tags.ExpGui_event_triggers
        if event_triggers and table.array_contains(event_triggers, self.uid) then
            error("Element::triggers_events should not be called on the value you return from the definition")
        end
    elseif self.name then
        error("Static name \""..self.name.."\" expected but no element was returned from the definition")
    end

    -- Register events by default, but allow skipping them
    if no_events == self.no_events then
        return element
    else
        return element and self:triggers_events(element)
    end
end

--- Get where a function was defined as a string
local function get_defined_at(level)
    local debug_info = debug.getinfo(level, "Sn")
    local file_name = debug_info.source:match('^.+/currently%-playing/(.+)$'):sub(1, -5)
    local func_name = debug_info.name or ("<anonymous:"..debug_info.linedefined..">")
    return file_name..":"..func_name
end

--- Element Define.
-- @section elementDefine

--[[-- Used to define new elements for your gui, can be used like LuaGuiElement.add or a custom function
@tparam ?table|function element_define the define information for the gui element, same data as LuaGuiElement.add, or a custom function may be used
@treturn table the new element define, this can be considered a factory for the element which can be called to draw the element to any other element

@usage-- Using element defines like LuaGuiElement.add
-- This returns a factory function to draw a button with the caption "Example Button"
local example_button =
Gui.element{
    type = 'button',
    caption = 'Example Button'
}

@usage-- Using element defines with a custom factory function
-- This method can be used if you still want to be able register event handlers but it is too complex to be compatible with LuaGuiElement.add
local example_flow_with_button =
Gui.element(function(event_trigger, parent, ...)
    -- ... shows that all other arguments from the factory call are passed to this function
    -- parent is the element which was passed to the factory function where you should add your new element
    -- here we are adding a flow which we will then later add a button to
    local flow =
    parent.add{
        name = 'example_flow',
        type = 'flow'
    }

    -- event_trigger should be the name of any elements you want to trigger your event handlers, such as on_click or on_state_changed
    -- now we add the button to the flow that we created earlier
    local element =
    flow.add{
        name = event_trigger,
        type = 'button',
        caption = 'Example Button'
    }

    -- you must return your new element, this is so styles can be applied and returned to the caller
    -- you may return any of your elements that you add, consider the context in which it will be used for what should be returned
    return element
end)

]]
function Gui.element(element_define)
    _C.error_if_runtime()
    -- Set the metatable to allow access to register events
    local element = setmetatable({}, Gui._mt_element)

    -- Increment the uid counter
    local uid = Gui.uid + 1
    Gui.uid = uid
    element.uid = uid
    Gui.debug_info[uid] = { draw = 'None', style = 'None', events = {} }

    -- Add the definition function
    if type(element_define) == 'table' then
        Gui.debug_info[uid].draw = element_define
        if element_define.name == Gui.unique_static_name then
            element_define.name = "ExpGui_"..tostring(uid)
        end
        for k, v in pairs(element_define) do
            if element[k] == nil then
                element[k] = v
            end
        end
        element._draw = function(_, parent)
            return parent.add(element_define)
        end
    else
        Gui.debug_info[uid].draw = get_defined_at(element_define)
        element._draw = element_define
    end

    -- Add the define to the base module
    element.defined_at = get_defined_at(3)
    Gui.file_paths[uid] = element.defined_at
    Gui.defines[uid] = element

    -- Return the element so event handers can be accessed
    return element
end

--[[-- Used to extent your element define with a style factory, this style will be applied to your element when created, can also be a custom function
@tparam ?table|function style_define style table where each key and value pair is treated like LuaGuiElement.style[key] = value, a custom function can be used
@treturn table the element define is returned to allow for event handlers to be registered

@usage-- Using the table method of setting the style
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

@usage-- Using the function method to set the style
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

]]
function Gui._prototype_element:style(style_define)
    _C.error_if_runtime()
    -- Add the definition function
    if type(style_define) == 'table' then
        Gui.debug_info[self.uid].style = style_define
        self._style = function(style)
            for key, value in pairs(style_define) do
                style[key] = value
            end
        end
    else
        Gui.debug_info[self.uid].style = get_defined_at(style_define)
        self._style = style_define
    end

    -- Return the element so event handers can be accessed
    return self
end

--[[-- Enforce the fact the element has a static name, this is required for the cases when a function define is used
@tparam[opt] string element The element that will trigger calls to the event handlers
@treturn table the element define is returned to allow for event handlers to be registered
]]
function Gui._prototype_element:static_name(name)
    _C.error_if_runtime()
    if name == Gui.unique_static_name then
        self.name = "ExpGui_"..tostring(self.uid)
    else
        self.name = name
    end
    return self
end

--[[-- Used to link an element to an element define such that any event on the element will call the handlers on the element define
-- You should not call this on the element you return from your constructor because this is done automatically
@tparam LuaGuiElement element The element that will trigger calls to the event handlers
@treturn LuaGuiElement The element passed as the argument to allow for cleaner returns
]]
function Gui._prototype_element:triggers_events(element)
    if not self._has_events then return element end
    local tags = element.tags
    if not tags then
        element.tags = { ExpGui_event_triggers = { self.uid } }
        return element
    elseif not tags.ExpGui_event_triggers then
        tags.ExpGui_event_triggers = { self.uid }
    elseif table.array_contains(tags.ExpGui_event_triggers, self.uid) then
        error("Element::triggers_events called multiple times on the same element with the same definition")
    else
        table.insert(tags.ExpGui_event_triggers, self.uid)
    end
    -- To modify a set of tags, the whole table needs to be written back to the respective property.
    element.tags = tags
    return element
end

--- Explicitly skip events on the element returned by your definition function
function Gui._prototype_element:no_events(element)
    return element, self.no_events
end

--[[-- Set the handler which will be called for a custom event, only one handler can be used per event per element
@tparam string event_name the name of the event you want to handler to be called on, often from Gui.events
@tparam function handler the handler that you want to be called when the event is raised
@treturn table the element define so more handleres can be registered

@usage-- Register a handler to "my_custom_event" for this element
element_deinfe:on_event('my_custom_event', function(event)
    event.player.print(player.name)
end)

]]
function Gui._prototype_element:on_event(event_name, handler)
    _C.error_if_runtime()
    table.insert(Gui.debug_info[self.uid].events, event_name)
    Gui.events[event_name] = event_name
    self[event_name] = handler
    self._has_events = true
    return self
end

--[[-- Raise the handler which is attached to an event; external use should be limited to custom events
@tparam table event the event table passed to the handler, must contain fields: name, element
@treturn table the element define so more events can be raised

@usage Raising a custom event
element_define:raise_event{
    name = 'my_custom_event',
    element = element
}

]]
function Gui._prototype_element:raise_event(event)
    -- Check the element is valid
    local element = event.element
    if not element or not element.valid then
        return self
    end

    -- Get the event handler for this element
    local handler = self[event.name]
    if not handler then
        return self
    end

    -- Get the player for this event
    local player_index = event.player_index or element.player_index
    local player = game.players[player_index]
    if not player or not player.valid then
        return self
    end
    event.player = player

    local success, err = xpcall(handler, debug.traceback, player, element, event)
    if not success then
        error('There as been an error with an event handler for a gui element:\n\t'..err)
    end
    return self
end

-- This function is used to link element define events and the events from the factorio api
local function event_handler_factory(event_name)
    Event.add(event_name, function(event)
        local element = event.element
        if not element or not element.valid then return end
        local event_triggers = element.tags.ExpGui_event_triggers
        if not event_triggers then return end
        for _, uid in pairs(event_triggers) do
            local element_define = Gui.defines[uid]
            if element_define then
                element_define:raise_event(event)
            end
        end
    end)

    Gui.events[event_name] = event_name
    return function(self, handler)
        return self:on_event(event_name, handler)
    end
end

--- Element Events.
-- @section elementEvents

--- Called when the player opens a GUI.
-- @tparam function handler the event handler which will be called
-- @usage element_define:on_open(function(event)
--  event.player.print(table.inspect(event))
--end)
Gui._prototype_element.on_open = event_handler_factory(defines.events.on_gui_opened)

--- Called when the player closes the GUI they have open.
-- @tparam function handler the event handler which will be called
-- @usage element_define:on_close(function(event)
--  event.player.print(table.inspect(event))
--end)
Gui._prototype_element.on_close = event_handler_factory(defines.events.on_gui_closed)

--- Called when LuaGuiElement is clicked.
-- @tparam function handler the event handler which will be called
-- @usage element_define:on_click(function(event)
--  event.player.print(table.inspect(event))
--end)
Gui._prototype_element.on_click = event_handler_factory(defines.events.on_gui_click)

--- Called when a LuaGuiElement is confirmed, for example by pressing Enter in a textfield.
-- @tparam function handler the event handler which will be called
-- @usage element_define:on_confirmed(function(event)
--  event.player.print(table.inspect(event))
--end)
Gui._prototype_element.on_confirmed = event_handler_factory(defines.events.on_gui_confirmed)

--- Called when LuaGuiElement checked state is changed (related to checkboxes and radio buttons).
-- @tparam function handler the event handler which will be called
-- @usage element_define:on_checked_changed(function(event)
--  event.player.print(table.inspect(event))
--end)
Gui._prototype_element.on_checked_changed = event_handler_factory(defines.events.on_gui_checked_state_changed)

--- Called when LuaGuiElement element value is changed (related to choose element buttons).
-- @tparam function handler the event handler which will be called
-- @usage element_define:on_elem_changed(function(event)
--  event.player.print(table.inspect(event))
--end)
Gui._prototype_element.on_elem_changed = event_handler_factory(defines.events.on_gui_elem_changed)

--- Called when LuaGuiElement element location is changed (related to frames in player.gui.screen).
-- @tparam function handler the event handler which will be called
-- @usage element_define:on_location_changed(function(event)
--  event.player.print(table.inspect(event))
--end)
Gui._prototype_element.on_location_changed = event_handler_factory(defines.events.on_gui_location_changed)

--- Called when LuaGuiElement selected tab is changed (related to tabbed-panes).
-- @tparam function handler the event handler which will be called
-- @usage element_define:on_tab_changed(function(event)
--  event.player.print(table.inspect(event))
--end)
Gui._prototype_element.on_tab_changed = event_handler_factory(defines.events.on_gui_selected_tab_changed)

--- Called when LuaGuiElement selection state is changed (related to drop-downs and listboxes).
-- @tparam function handler the event handler which will be called
-- @usage element_define:on_selection_changed(function(event)
--  event.player.print(table.inspect(event))
--end)
Gui._prototype_element.on_selection_changed = event_handler_factory(defines.events.on_gui_selection_state_changed)

--- Called when LuaGuiElement switch state is changed (related to switches).
-- @tparam function handler the event handler which will be called
-- @usage element_define:on_switch_changed(function(event)
--  event.player.print(table.inspect(event))
--end)
Gui._prototype_element.on_switch_changed = event_handler_factory(defines.events.on_gui_switch_state_changed)

--- Called when LuaGuiElement text is changed by the player.
-- @tparam function handler the event handler which will be called
-- @usage element_define:on_text_changed(function(event)
--  event.player.print(table.inspect(event))
--end)
Gui._prototype_element.on_text_changed = event_handler_factory(defines.events.on_gui_text_changed)

--- Called when LuaGuiElement slider value is changed (related to the slider element).
-- @tparam function handler the event handler which will be called
-- @usage element_define:on_value_changed(function(event)
--  event.player.print(table.inspect(event))
--end)
Gui._prototype_element.on_value_changed = event_handler_factory(defines.events.on_gui_value_changed)

-- Module return
return Gui
