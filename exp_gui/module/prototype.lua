
local ExpUtil = require("modules/exp_util")

local GuiData = require("modules/exp_gui/data")
local GuiIter = require("modules/exp_gui/iter")

--- @class _ExpElement
local ExpElement = {
    _elements = {}, --- @type table<string, ExpElement>
}

ExpElement.events = {}

--- @alias ExpElement.DrawCallback fun(def: ExpElement, parent: LuaGuiElement, ...): LuaGuiElement?, function?
--- @alias ExpElement.PostDrawCallback fun(def: ExpElement, element: LuaGuiElement?, parent: LuaGuiElement, ...): table?
--- @alias ExpElement.PostDrawCallbackAdder fun(self: ExpElement, definition: table | number | string | boolean | ExpElement.PostDrawCallback): ExpElement
--- @alias ExpElement.EventHandler<E> fun(def: ExpElement, player: LuaPlayer, element: LuaGuiElement, event: E)
--- @alias ExpElement.OnEventAdder<E> fun(self: ExpElement, handler: fun(def: ExpElement, player: LuaPlayer, element: LuaGuiElement, event: E)): ExpElement

--- @class ExpElement._debug
--- @field defined_at string
--- @field draw_definition table?
--- @field draw_signals table?
--- @field style_definition table?
--- @field style_from_args table?
--- @field element_data_definition table?
--- @field element_data_from_args table?
--- @field player_data_definition table?
--- @field player_data_from_args table?
--- @field force_data_definition table?
--- @field force_data_from_args table?
--- @field global_data_definition table?
--- @field global_data_from_args table?

--- @class ExpElement
--- @field name string
--- @field data GuiData
--- @field _debug ExpElement._debug
--- @field _draw ExpElement.DrawCallback?
--- @field _style ExpElement.PostDrawCallback?
--- @field _element_data ExpElement.PostDrawCallback?
--- @field _player_data ExpElement.PostDrawCallback?
--- @field _force_data ExpElement.PostDrawCallback?
--- @field _global_data ExpElement.PostDrawCallback?
--- @field _events table<defines.events, ExpElement.EventHandler<EventData>[]>
--- @overload fun(parent: LuaGuiElement, ...: any): LuaGuiElement
ExpElement._prototype = {
    _track_elements = false,
    _has_handlers = false,
}

ExpElement._metatable = {
    __call = nil, -- ExpElement._prototype.create
    __index = ExpElement._prototype,
    __class = "ExpElement",
}

--- Used to signal the intentional lack of a return value from draw
--- @return nil, function
function ExpElement.no_return()
    return nil, ExpElement.no_return
end

--- Used to signal that the property should be the same as the define name
--- @return function
function ExpElement.from_name()
    return ExpElement.from_name
end

--- Used to signal that a property should be taken from the arguments, a string means key of last arg
--- @generic A: number|string, D: any
--- @param arg A
--- @param default D?
--- @return [function, A, D]
function ExpElement.from_argument(arg, default)
    return { ExpElement.from_argument, assert(arg), default }
end

--- @alias ExpElement._signals table<string|number, [string, any]> | [function, string|number, any|nil]

--- Extract the from args properties from a definition
--- @param definition table
--- @return ExpElement._signals
function ExpElement._prototype:_extract_signals(definition)
    -- Check if the definition is from_argument
    if definition[1] == ExpElement.from_argument then
        return definition
    end

    -- Otherwise check if any of the values are from_argument or from_name
    local signals = {}
    for prop, value in pairs(definition) do
        if value == ExpElement.from_argument then
            error("ExpElement.from_argument must be called with an argument index / key")
        elseif value == ExpElement.from_name then
            definition[prop] = self.name
        elseif type(value) == "table" and rawget(value, 1) == ExpElement.from_argument then
            local key = value[2] or (#signals + 1)
            signals[key] = { prop, value[3] }
        end
    end

    return signals
end

--- Apply the previously extracted signals to a definition using the create args
--- @param definition table
--- @param signals ExpElement._signals
--- @param args table
--- @return any
function ExpElement._prototype:_apply_signals(definition, signals, args)
    local last = args[#args] or args -- 'or args' used instead of empty table
    -- Check if the root is from_argument
    if signals[1] == ExpElement.from_argument then
        local key, rtn = signals[2], nil
        if type(key) == "string" then
            rtn = last[key]
        else
            rtn = args[key]
        end
        if rtn == nil then
            return signals[3]
        end
        return rtn
    end

    -- Otherwise set the properties of the definition
    for i, pair in pairs(signals) do
        local key = pair[1]
        if type(i) == "string" then
            definition[key] = last[i]
        else
            definition[key] = args[i]
        end
        if definition[key] == nil then
            definition[key] = pair[2]
        end
    end

    return definition
end

--- Register a new instance of a prototype
--- @param name string
--- @return ExpElement
function ExpElement.new(name)
    ExpUtil.assert_not_runtime()
    local module_name = ExpUtil.get_module_name(2)
    local element_name = module_name .. "/" .. name
    assert(ExpElement._elements[element_name] == nil, "ExpElement already defined with name: " .. name)

    local instance = {
        name = element_name,
        data = GuiData.create(element_name),
        _events = {},
        _debug = {
            defined_at = ExpUtil.get_current_line(2),
        },
    }

    ExpElement._elements[element_name] = instance --[[ @as ExpElement ]]
    return setmetatable(instance, ExpElement._metatable)
end

--- Get an element by its name
--- @param name string
--- @return ExpElement
function ExpElement.get(name)
    return assert(ExpElement._elements[name], "ExpElement is not defined: " .. tostring(name))
end

--- Create a new instance of this element definition
--- @param parent LuaGuiElement
--- @param ... any
--- @return LuaGuiElement?
function ExpElement._prototype:create(parent, ...)
    assert(self._draw, "Element does not have a draw definition")
    local element, status = self:_draw(parent, ...)
    local player = assert(game.get_player(parent.player_index))
    if status ~= ExpElement.no_return then
        assert(element and element.object_name == "LuaGuiElement", "Draw did not return a LuaGuiElement")
    end

    if self._style then
        assert(element, "Cannot set style when no element was returned by draw definition")
        local style = self:_style(element, parent, ...)
        if style then
            local element_style = element.style
            for k, v in pairs(style) do
                element_style[k] = v
            end
        end
    end

    if self._element_data then
        assert(element, "Cannot set element data when no element was returned by draw definition")
        local data = self:_element_data(element, parent, ...)
        if data ~= nil and self.data[element] == nil then
            self.data[element] = data
        end
    end

    if self._player_data then
        local data = self:_player_data(element, parent, ...)
        if data ~= nil and self.data[player] == nil then
            self.data[player] = data
        end
    end

    if self._force_data then
        local data = self:_force_data(element, parent, ...)
        if data ~= nil and self.data[player.force] == nil then
            self.data[player.force] = data
        end
    end

    if self._global_data then
        local data = self:_global_data(element, parent, ...)
        if data then
            local global_data = self.data.global_data
            for k, v in pairs(data) do
                if global_data[k] == nil then
                    global_data[k] = v
                end
            end
        end
    end

    if not element then return end

    if self._track_elements and status ~= ExpElement._prototype.track_element and status ~= ExpElement._prototype.untrack_element then
        self:track_element(element)
    end

    if self._has_handlers and status ~= ExpElement._prototype.link_element and status ~= ExpElement._prototype.unlink_element then
        self:link_element(element)
    end

    return element
end

--- Enable tracking of all created elements
--- @return ExpElement
function ExpElement._prototype:track_all_elements()
    ExpUtil.assert_not_runtime()
    self._track_elements = true
    return self
end

--- Add a temp draw definition, useful for when working top down
--- @return ExpElement
function ExpElement._prototype:empty()
    log("empty draw used for " .. self.name)
    return self:draw{
        type = "flow"
    }
end

--- @alias ExpElement.add_param LuaGuiElement.add_param | table<string, [function, number|string|nil] | function>

--- Set the draw definition
--- @param definition ExpElement.add_param | ExpElement.DrawCallback
--- @return ExpElement
function ExpElement._prototype:draw(definition)
    ExpUtil.assert_not_runtime()
    if type(definition) == "function" and definition ~= ExpElement.from_argument then
        self._draw = definition
        return self
    end

    assert(type(definition) == "table", "Definition is not a table or function")
    local signals = self:_extract_signals(definition)
    self._debug.draw_definition = definition

    if not next(signals) then
        -- If no signals then skip var arg
        self._draw = function(_, parent)
            return parent.add(definition)
        end
        return self
    end

    self._debug.draw_signals = signals
    self._draw = function(_, parent, ...)
        return parent.add(self:_apply_signals(definition, signals, { ... }))
    end

    return self
end

--- Create a definition adder for anything other than draw
--- @param prop_name string
--- @param debug_def string
--- @param debug_signals string
--- @return ExpElement.PostDrawCallbackAdder
local function definition_factory(prop_name, debug_def, debug_signals)
    return function(self, definition)
        ExpUtil.assert_not_runtime()
        if type(definition) == "function" and definition ~= ExpElement.from_argument then
            self[prop_name] = definition
            return self
        end

        if type(definition) ~= "table" and definition ~= ExpElement.from_argument then
            -- Primitive value so we can just return it
            self[prop_name] = function(_, _, _)
                return definition
            end
            return self
        end

        assert(type(definition) == "table", "Definition is not a table or function")
        local signals = self:_extract_signals(definition)
        self._debug[debug_def] = definition

        if not next(signals) then
            -- If no signals then skip var arg
            self[prop_name] = function(_, _, _)
                return table.deep_copy(definition)
            end
            return self
        end

        self._debug[debug_signals] = signals
        self[prop_name] = function(_, _, _, ...)
            return self:_apply_signals(table.deep_copy(definition), signals, { ... })
        end

        return self
    end
end

--- Set the style definition
--- @type ExpElement.PostDrawCallbackAdder
ExpElement._prototype.style = definition_factory("_style", "style_definition", "style_signals")

--- Set the default element data
--- @type ExpElement.PostDrawCallbackAdder
ExpElement._prototype.element_data = definition_factory("_element_data", "element_data_definition", "element_data_signals")

--- Set the default player data
--- @type ExpElement.PostDrawCallbackAdder
ExpElement._prototype.player_data = definition_factory("_player_data", "player_data_definition", "player_data_signals")

--- Set the default force data
--- @type ExpElement.PostDrawCallbackAdder
ExpElement._prototype.force_data = definition_factory("_force_data", "force_data_definition", "force_data_signals")

--- Set the default global data
--- @type ExpElement.PostDrawCallbackAdder
ExpElement._prototype.global_data = definition_factory("_global_data", "global_data_definition", "global_data_signals")

--- Iterate the tracked elements of all players
--- @param filter GuiIter.FilterType
--- @return GuiIter.ReturnType
function ExpElement._prototype:tracked_elements(filter)
    return GuiIter.get_tracked_elements(self.name, filter)
end

--- Iterate the tracked elements of all online players
--- @param filter GuiIter.FilterType
--- @return GuiIter.ReturnType
function ExpElement._prototype:online_elements(filter)
    return GuiIter.get_online_elements(self.name, filter)
end

--- Track an arbitrary element, tracked elements can be iterated
--- @param element LuaGuiElement
--- @return LuaGuiElement
--- @return function
function ExpElement._prototype:track_element(element)
    GuiIter.add_element(self.name, element)
    return element, ExpElement._prototype.track_element
end

--- Untrack an arbitrary element, untracked elements can't be iterated
--- @param element LuaGuiElement
--- @return LuaGuiElement
--- @return function
function ExpElement._prototype:untrack_element(element)
    GuiIter.remove_element(self.name, element.player_index, element.index)
    return element, ExpElement._prototype.untrack_element
end

--- Link an arbitrary element, linked elements call event handlers
--- @param element LuaGuiElement
--- @return LuaGuiElement
--- @return function
function ExpElement._prototype:link_element(element)
    assert(self._has_handlers, "Element has no event handlers")
    local element_tags = element.tags
    if not element_tags then
        element_tags = {}
    end

    local event_tags = element_tags["Gui"]
    if not event_tags then
        event_tags = {}
        element_tags["Gui"] = event_tags
    end
    --- @cast event_tags string[]

    if not table.array_contains(event_tags, self.name) then
        event_tags[#event_tags + 1] = self.name
    end

    element.tags = element_tags
    return element, ExpElement._prototype.link_element
end

--- Unlink an arbitrary element, unlinked elements do not call event handlers
--- @param element LuaGuiElement
--- @return LuaGuiElement
--- @return function
function ExpElement._prototype:unlink_element(element)
    assert(self._has_handlers, "Element has no event handlers")
    local element_tags = element.tags
    if not element_tags then
        return element, ExpElement._prototype.unlink_element
    end

    local event_tags = element_tags["Gui"]
    if not event_tags then
        event_tags = {}
        element_tags["Gui"] = event_tags
    end
    --- @cast event_tags string[]

    table.remove_element(event_tags, self.name)
    element.tags = element_tags
    return element, ExpElement._prototype.unlink_element
end

--- Handle any gui events
--- @param event EventData.on_gui_click
local function event_handler(event)
    local element = event.element
    if not element or not element.valid then return end

    local event_tags = element.tags and element.tags["Gui"]
    if not event_tags then return end
    --- @cast event_tags string[]

    for _, define_name in ipairs(event_tags) do
        local define = ExpElement._elements[define_name]
        if define then
            define:raise_event(event)
        end
    end
end

--- Raise all handlers for an event on this definition
--- @param event EventData | { element: LuaGuiElement, player_index: number? }
function ExpElement._prototype:raise_event(event)
    local handlers = self._events[event.name]
    if not handlers then return end
    local player = event.player_index and game.get_player(event.player_index)
    if event.element then player = game.get_player(event.element.player_index) end
    for _, handler in ipairs(handlers) do
        -- All gui elements will contain player and element, other events might have these as nil
        -- Therefore only the signature of on_event has these values as optional
        handler(self, player --[[ @as LuaPlayer ]], event.element, event --[[ @as EventData ]])
    end
end

--- Add an event handler
--- @param event defines.events
--- @param handler fun(def: ExpElement, player: LuaPlayer?, element: LuaGuiElement?, event: EventData)
--- @return ExpElement
function ExpElement._prototype:on_event(event, handler)
    ExpElement.events[event] = event_handler
    self._has_handlers = true

    local handlers = self._events[event] or {}
    handlers[#handlers + 1] = handler
    self._events[event] = handlers

    return self
end

--- Create a function to add event handlers to an element definition
--- @param event defines.events
--- @return ExpElement.OnEventAdder<EventData>
local function event_factory(event)
    return function(self, handler)
        return self:on_event(event, handler)
    end
end

--- Called when LuaGuiElement checked state is changed (related to checkboxes and radio buttons).
--- @type ExpElement.OnEventAdder<EventData.on_gui_checked_state_changed>
ExpElement._prototype.on_checked_state_changed = event_factory(defines.events.on_gui_checked_state_changed)

--- Called when LuaGuiElement is clicked.
--- @type ExpElement.OnEventAdder<EventData.on_gui_click>
ExpElement._prototype.on_click = event_factory(defines.events.on_gui_click)

--- Called when the player closes the GUI they have open.
--- @type ExpElement.OnEventAdder<EventData.on_gui_closed>
ExpElement._prototype.on_closed = event_factory(defines.events.on_gui_closed)

--- Called when a LuaGuiElement is confirmed, for example by pressing Enter in a textfield.
--- @type ExpElement.OnEventAdder<EventData.on_gui_confirmed>
ExpElement._prototype.on_confirmed = event_factory(defines.events.on_gui_confirmed)

--- Called when LuaGuiElement element value is changed (related to choose element buttons).
--- @type ExpElement.OnEventAdder<EventData.on_gui_elem_changed>
ExpElement._prototype.on_elem_changed = event_factory(defines.events.on_gui_elem_changed)

--- Called when LuaGuiElement is hovered by the mouse.
--- @type ExpElement.OnEventAdder<EventData.on_gui_hover>
ExpElement._prototype.on_hover = event_factory(defines.events.on_gui_hover)

--- Called when the player's cursor leaves a LuaGuiElement that was previously hovered.
--- @type ExpElement.OnEventAdder<EventData.on_gui_leave>
ExpElement._prototype.on_leave = event_factory(defines.events.on_gui_leave)

--- Called when LuaGuiElement element location is changed (related to frames in player.gui.screen).
--- @type ExpElement.OnEventAdder<EventData.on_gui_location_changed>
ExpElement._prototype.on_location_changed = event_factory(defines.events.on_gui_location_changed)

--- Called when the player opens a GUI.
--- @type ExpElement.OnEventAdder<EventData.on_gui_opened>
ExpElement._prototype.on_opened = event_factory(defines.events.on_gui_opened)

--- Called when LuaGuiElement selected tab is changed (related to tabbed-panes).
--- @type ExpElement.OnEventAdder<EventData.on_gui_selected_tab_changed>
ExpElement._prototype.on_selected_tab_changed = event_factory(defines.events.on_gui_selected_tab_changed)

--- Called when LuaGuiElement selection state is changed (related to drop-downs and listboxes).
--- @type ExpElement.OnEventAdder<EventData.on_gui_selection_state_changed>
ExpElement._prototype.on_selection_state_changed = event_factory(defines.events.on_gui_selection_state_changed)

--- Called when LuaGuiElement switch state is changed (related to switches).
--- @type ExpElement.OnEventAdder<EventData.on_gui_switch_state_changed>
ExpElement._prototype.on_switch_state_changed = event_factory(defines.events.on_gui_switch_state_changed)

--- Called when LuaGuiElement text is changed by the player.
--- @type ExpElement.OnEventAdder<EventData.on_gui_text_changed>
ExpElement._prototype.on_text_changed = event_factory(defines.events.on_gui_text_changed)

--- Called when LuaGuiElement slider value is changed (related to the slider element).
--- @type ExpElement.OnEventAdder<EventData.on_gui_value_changed>
ExpElement._prototype.on_value_changed = event_factory(defines.events.on_gui_value_changed)

ExpElement._metatable.__call = ExpElement._prototype.create
return ExpElement
