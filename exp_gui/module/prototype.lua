
local ExpUtil = require("modules/exp_util")

local GuiData = require("./data")
local GuiIter = require("./iter")

--- @class ExpGui_ExpElement
local ExpElement = {
    _elements = {}
}

--- @alias ExpElement.DrawCallback fun(def: ExpElement, parent: LuaGuiElement, ...): LuaGuiElement?, function?
--- @alias ExpElement.StyleCallback fun(def: ExpElement, element: LuaGuiElement?, parent: LuaGuiElement, ...): table?
--- @alias ExpElement.DataCallback fun(def: ExpElement, element: LuaGuiElement?, parent: LuaGuiElement, ...): table?
--- @alias ExpElement.OnEventAdder<E> fun(self: ExpElement, handler: fun(def: ExpElement, event: E)): ExpElement

--- @class ExpElement._debug
--- @field defined_at string
--- @field draw_src table?
--- @field style_src table?

--- @class ExpElement
--- @field name string
--- @field scope string
--- @field data ExpGui.GuiData
--- @field _debug ExpElement._debug
--- @field _draw ExpElement.DrawCallback?
--- @field _style ExpElement.StyleCallback?
--- @field _element_data ExpElement.DataCallback?
--- @field _player_data ExpElement.DataCallback?
--- @field _force_data ExpElement.DataCallback?
--- @field _events table<defines.events, function[]>
ExpElement._prototype = {
    _track_elements = false,
    _has_handlers = false,
}

ExpElement._metatable = {
    __call = nil, -- ExpElement._prototype.create
    __index = ExpElement._prototype,
    __class = "ExpGui",
}

--- Register a new instance of a prototype
--- @param name string
--- @return ExpElement
function ExpElement.create(name)
    ExpUtil.assert_not_runtime()
    assert(ExpElement._elements[name] == nil, "ExpElement already defined with name: " .. name)
    local scope = ExpUtil.get_module_name(2) .. "::" .. name

    local instance = {
        name = name,
        scope = scope,
        data = GuiData.create(scope),
        _events = {},
        _debug = {
            defined_at = ExpUtil.safe_file_path(2),
        },
    }

    ExpElement._elements[name] = instance
    return setmetatable(instance, ExpElement._metatable)
end

--- Create a new instance of this element definition
--- @param parent LuaGuiElement
--- @param ... any
--- @return LuaGuiElement?
function ExpElement._prototype:create(parent, ...)
    assert(self._draw, "Element does not have a draw definition")
    local element, status = self:_draw(parent, ...)
    local player = assert(game.get_player(parent.player_index))

    if self._style then
        local style = self:_style(element, parent, ...)
        if style then
            assert(element, "Cannot set style when no element was returned by draw definition")
            local element_style = element.style
            for k, v in pairs(style) do
                element_style[k] = v
            end
        end
    end

    if self._element_data then
        local data = self:_element_data(element, parent, ...)
        if data then
            assert(element, "Cannot set element data when no element was returned by draw definition")
            self.data[element] = data
        end
    end

    if self._player_data then
        local data = self:_player_data(element, parent, ...)
        if data then
            self.data[player] = data
        end
    end

    if self._force_data then
        local data = self:_force_data(element, parent, ...)
        if data then
            self.data[player.force] = data
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
    self._track_elements = true
    return self
end

--- Set the draw definition
--- @param definition table | ExpElement.DrawCallback
--- @return ExpElement
function ExpElement._prototype:draw(definition)
    if type(definition) == "table" then
        self._debug.draw_src = definition
        self._draw = function(_, parent)
            return parent.add(definition)
        end
    else
        self._draw = definition
    end

    return self
end

--- Set the style definition
--- @param definition table | ExpElement.StyleCallback
--- @return ExpElement
function ExpElement._prototype:style(definition)
    if type(definition) == "table" then
        self._debug.style_src = definition
        self._style = function(_, parent)
            return parent.add(definition)
        end
    else
        self._style = definition
    end

    return self
end

--- Set the default element data
--- @param definition table | ExpElement.DataCallback
--- @return ExpElement
function ExpElement._prototype:element_data(definition)
    if type(definition) == "table" then
        --- @diagnostic disable-next-line invisible
        self.data._init.element = definition
    else
        self._element_data = definition
    end

    return self
end

--- Set the default player data
--- @param definition table | ExpElement.DataCallback
--- @return ExpElement
function ExpElement._prototype:player_data(definition)
    if type(definition) == "table" then
        --- @diagnostic disable-next-line invisible
        self.data._init.player = definition
    else
        self._player_data = definition
    end

    return self
end

--- Set the default force data
--- @param definition table | ExpElement.DataCallback
--- @return ExpElement
function ExpElement._prototype:force_data(definition)
    if type(definition) == "table" then
        --- @diagnostic disable-next-line invisible
        self.data._init.force = definition
    else
        self._force_data = definition
    end

    return self
end

--- Iterate the tracked elements of all players
--- @param filter ExpGui_GuiIter.FilterType
--- @return ExpGui_GuiIter.ReturnType
function ExpElement._prototype:tracked_elements(filter)
    return GuiIter.get_tracked_elements(self.scope, filter)
end

--- Iterate the tracked elements of all online players
--- @param filter ExpGui_GuiIter.FilterType
--- @return ExpGui_GuiIter.ReturnType
function ExpElement._prototype:online_elements(filter)
    return GuiIter.get_online_elements(self.scope, filter)
end

--- Track an arbitrary element, tracked elements can be iterated
--- @param element LuaGuiElement
--- @return LuaGuiElement
--- @return function
function ExpElement._prototype:track_element(element)
    GuiIter.add_element(self.scope, element)
    return element, ExpElement._prototype.track_element
end

--- Untrack an arbitrary element, untracked elements can't be iterated
--- @param element LuaGuiElement
--- @return LuaGuiElement
--- @return function
function ExpElement._prototype:untrack_element(element)
    GuiIter.remove_element(self.scope, element.player_index, element.index)
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

    local event_tags = element_tags["ExpGui"]
    if not event_tags then
        event_tags = {}
        element_tags["ExpGui"] = event_tags
    end
    --- @cast event_tags string[]

    if not table.array_contains(event_tags, self.scope) then
        event_tags[#event_tags + 1] = self.scope
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
        element_tags = {}
    end

    local event_tags = element_tags["ExpGui"]
    if not event_tags then
        event_tags = {}
        element_tags["ExpGui"] = event_tags
    end
    --- @cast event_tags string[]

    table.remove_element(event_tags, self.scope)
    element.tags = element_tags
    return element, ExpElement._prototype.unlink_element
end

local e = defines.events
local events = {
}

--- Create a function to add event handlers to an element definition
--- @param event_name any
--- @return ExpElement.OnEventAdder<EventData>
local function event_factory(event_name)
    --- @param event EventData.on_gui_click
    events[event_name] = function(event)
        local element = event.element
        if not element or not element.valid then return end

        local event_tags = element.tags and element.tags["ExpGui"]
        if not event_tags then return end
        --- @cast event_tags string[]

        for _, define_name in ipairs(event_tags) do
            local define = ExpElement._elements[define_name]
            if define then
                define:_raise_event(event)
            end
        end
    end

    return function(self, handler)
        self._has_handlers = true
        local handlers = self._events[event_name]
        if not handlers then
            handlers = {}
            self._events[event_name] = handlers
        end
        handlers[#handlers + 1] = handler
        return self
    end
end

--- Raise all handlers for an event on this definition
--- @param event EventData
function ExpElement._prototype:_raise_event(event)
    local handlers = self._events[event.name]
    if not handlers then return end
    for _, handler in ipairs(handlers) do
        handler(self, event)
    end
end

--- Called when LuaGuiElement checked state is changed (related to checkboxes and radio buttons).
--- @type ExpElement.OnEventAdder<EventData.on_gui_checked_state_changed>
ExpElement._prototype.on_checked_state_changed = event_factory(e.on_gui_checked_state_changed)

--- Called when LuaGuiElement is clicked.
--- @type ExpElement.OnEventAdder<EventData.on_gui_click>
ExpElement._prototype.on_click = event_factory(e.on_gui_click)

--- Called when the player closes the GUI they have open.
--- @type ExpElement.OnEventAdder<EventData.on_gui_closed>
ExpElement._prototype.on_closed = event_factory(e.on_gui_closed)

--- Called when a LuaGuiElement is confirmed, for example by pressing Enter in a textfield.
--- @type ExpElement.OnEventAdder<EventData.on_gui_confirmed>
ExpElement._prototype.on_confirmed = event_factory(e.on_gui_confirmed)

--- Called when LuaGuiElement element value is changed (related to choose element buttons).
--- @type ExpElement.OnEventAdder<EventData.on_gui_elem_changed>
ExpElement._prototype.on_elem_changed = event_factory(e.on_gui_elem_changed)

--- Called when LuaGuiElement is hovered by the mouse.
--- @type ExpElement.OnEventAdder<EventData.on_gui_hover>
ExpElement._prototype.on_hover = event_factory(e.on_gui_hover)

--- Called when the player's cursor leaves a LuaGuiElement that was previously hovered.
--- @type ExpElement.OnEventAdder<EventData.on_gui_leave>
ExpElement._prototype.on_leave = event_factory(e.on_gui_leave)

--- Called when LuaGuiElement element location is changed (related to frames in player.gui.screen).
--- @type ExpElement.OnEventAdder<EventData.on_gui_location_changed>
ExpElement._prototype.on_location_changed = event_factory(e.on_gui_location_changed)

--- Called when the player opens a GUI.
--- @type ExpElement.OnEventAdder<EventData.on_gui_opened>
ExpElement._prototype.on_opened = event_factory(e.on_gui_opened)

--- Called when LuaGuiElement selected tab is changed (related to tabbed-panes).
--- @type ExpElement.OnEventAdder<EventData.on_gui_selected_tab_changed>
ExpElement._prototype.on_selected_tab_changed = event_factory(e.on_gui_selected_tab_changed)

--- Called when LuaGuiElement selection state is changed (related to drop-downs and listboxes).
--- @type ExpElement.OnEventAdder<EventData.on_gui_selection_state_changed>
ExpElement._prototype.on_selection_state_changed = event_factory(e.on_gui_selection_state_changed)

--- Called when LuaGuiElement switch state is changed (related to switches).
--- @type ExpElement.OnEventAdder<EventData.on_gui_switch_state_changed>
ExpElement._prototype.on_switch_state_changed = event_factory(e.on_gui_switch_state_changed)

--- Called when LuaGuiElement text is changed by the player.
--- @type ExpElement.OnEventAdder<EventData.on_gui_text_changed>
ExpElement._prototype.on_text_changed = event_factory(e.on_gui_text_changed)

--- Called when LuaGuiElement slider value is changed (related to the slider element).
--- @type ExpElement.OnEventAdder<EventData.on_gui_value_changed>
ExpElement._prototype.on_value_changed = event_factory(e.on_gui_value_changed)

ExpElement._metatable.__call = ExpElement._prototype.create
ExpElement.events = events --- @package
return ExpElement
