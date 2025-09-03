--[[-- ExpUtil - Selection
Provides an easy way for working with selection planners
]]

local ExpUtil = require("modules/exp_util")

--- @class Selection.Active
--- @field name string
--- @field character LuaEntity?
--- @field data table

--- @alias Selection.event_handler<E> fun(event: E, ...: any)

--- @class ExpUtil_Selection
local Selection = {
    on_selection_start = script.generate_event_name(),
    --- @class EventData.on_selection_start: EventData
    --- @field player_index number
    --- @field selection Selection.Active

    on_selection_stop = script.generate_event_name(),
    --- @class EventData.on_selection_stop: EventData
    --- @field player_index number
    --- @field selection Selection.Active

    --- @type table<string, { [defines.events]: Selection.event_handler[] }>
    _registered = {},

    --- @package
    events = {},
}

--- @class Selection
--- @field name string
--- @field _handlers table
Selection._prototype = {}

Selection._metatable = {
    __index = Selection._prototype,
    __class = "Selection",
}

--- @type table<number, Selection.Active>
local script_data = {}
local Storage = require("modules/exp_util/storage")
Storage.register(script_data, function(tbl)
    script_data = tbl
end)

local empty_table = {}
local selection_tool = { name = "selection-tool" }

--- Test if a player is holding a selection tool
--- @param player LuaPlayer
--- @return boolean?
local function has_selection_tool_in_hand(player)
    return player.cursor_stack and player.cursor_stack.valid_for_read and player.cursor_stack.name == "selection-tool"
end

--- Give a selection tool to a player if they don't have one
--- @param player LuaPlayer
local function give_selection_tool(player)
    if has_selection_tool_in_hand(player) then return end
    player.clear_cursor()
    player.cursor_stack.set_stack(selection_tool)

    -- This does not work for selection planners, will make a feature request for it
    --player.cursor_stack_temporary = true

    -- Make a slot to place the selection tool even if inventory is full
    if player.character then
        player.character_inventory_slots_bonus = player.character_inventory_slots_bonus + 1
    end

    local inventory = player.get_main_inventory()
    if inventory then
        player.hand_location = { inventory = inventory.index, slot = #inventory }
    end
end

--- Remove a selection tool to a player if they have one
--- @param player LuaPlayer
--- @param old_character LuaEntity?
local function remove_selection_tool(player, old_character)
    -- Remove the selection tool
    if has_selection_tool_in_hand(player) then
        player.cursor_stack.clear()
    else
        player.remove_item(selection_tool)
    end

    -- Remove the extra slot
    if old_character and old_character == player.character then
        player.character_inventory_slots_bonus = player.character_inventory_slots_bonus - 1
        player.hand_location = nil
    end
end

--- Create a connection from which events can be registered
--- @param name string
--- @return Selection
function Selection.connect(name)
    ExpUtil.assert_not_runtime()
    ExpUtil.assert_argument_type(name, "string", 1, "name")

    local handlers = Selection._registered[name] or {}
    Selection._registered[name] = handlers

    return setmetatable({
        name = name,
        _handlers = handlers,
    }, Selection._metatable)
end

--- Stop the currently active selection for a player
--- @param player LuaPlayer
function Selection.stop(player)
    local player_index = player.index
    local active_selection = script_data[player_index]
    if not active_selection then
        return
    end

    remove_selection_tool(player, active_selection.character)

    script_data[player_index] = nil
    script.raise_event(Selection.on_selection_stop, {
        player_index = player_index,
        selection = active_selection,
    })
end

--- Start a new selection for a player
--- @param player LuaPlayer
--- @param ... unknown
function Selection._prototype:start(player, ...)
    local player_index = player.index
    local active_selection = script_data[player_index]
    if active_selection then
        script.raise_event(Selection.on_selection_stop, {
            player_index = player_index,
            selection = active_selection,
        })
    end

    local selection = {
        name = self.name,
        character = player.character,
        data = select("#", ...) > 0 and { ... } or empty_table,
    }

    give_selection_tool(player)

    script_data[player_index] = selection
    script.raise_event(Selection.on_selection_start, {
        player_index = player_index,
        selection = selection,
    })
end

--- Stop this selection if it is active, returns if this selection was active
--- @param player LuaPlayer
--- @return boolean
function Selection._prototype:stop(player)
    local player_index = player.index
    local active_selection = script_data[player_index]
    if not active_selection or active_selection.name ~= self.name then
        return false
    end

    remove_selection_tool(player, active_selection.character)

    script_data[player_index] = nil
    script.raise_event(Selection.on_selection_stop, {
        player_index = player_index,
        selection = active_selection,
    })

    return true
end

--- Dispatch events to the correct handlers
--- @param event EventData.on_player_selected_area | EventData.on_player_alt_selected_area | EventData.on_selection_start | EventData.on_selection_stop
local function event_dispatch(event)
    local active_selection = event.selection or script_data[event.player_index]
    local selection_handlers = active_selection and Selection._registered[active_selection.name]
    local handlers = selection_handlers and selection_handlers[event.name] or empty_table
    for _, handler in ipairs(handlers) do
        handler(event, table.unpack(active_selection.data))
    end
end

--- Create an on event adder
--- @param event defines.events
--- @return function
local function on_event_factory(event)
    return function(self, callback)
        ExpUtil.assert_not_runtime()
        ExpUtil.assert_argument_type(callback, "function", 1, "callback")
        Selection.events[event] = event_dispatch

        local handlers = self._handlers[event] or {}
        handlers[#handlers + 1] = callback
        self._handlers[event] = handlers
        return self
    end
end

local e = defines.events

--- @alias Selection.on_event<E> fun(self: Selection, callback: fun(event: E, ...: any)): Selection

--- @type Selection.on_event<EventData.on_selection_start>
Selection._prototype.on_start = on_event_factory(Selection.on_selection_start)

--- @type Selection.on_event<EventData.on_selection_stop>
Selection._prototype.on_stop = on_event_factory(Selection.on_selection_stop)

--- @type Selection.on_event<EventData.on_player_selected_area>
Selection._prototype.on_selection = on_event_factory(e.on_player_selected_area)

--- @type Selection.on_event<EventData.on_player_alt_selected_area>
Selection._prototype.on_alt_selection = on_event_factory(e.on_player_alt_selected_area)

--- Stop selection if the selection tool is removed from the cursor
--- @param event EventData.on_player_cursor_stack_changed
Selection.events[e.on_player_cursor_stack_changed] = function(event)
    local player = assert(game.get_player(event.player_index))
    if has_selection_tool_in_hand(player) then return end
    Selection.stop(player)
end

--- Make sure the hand location exists when the player returns from remote view
--- @param event EventData.on_player_controller_changed
Selection.events[e.on_player_controller_changed] = function(event)
    local player = assert(game.get_player(event.player_index))
    local inventory = player.get_main_inventory()
    if inventory and has_selection_tool_in_hand(player) then
        player.hand_location = { inventory = inventory.index, slot = #inventory }
    end
end

--- Stop selection after an event
--- @param event EventData.on_pre_player_left_game | EventData.on_pre_player_died
local function stop_after_event(event)
    local player = assert(game.get_player(event.player_index))
    Selection.stop(player)
end

Selection.events[e.on_pre_player_left_game] = stop_after_event
Selection.events[e.on_pre_player_died] = stop_after_event

return Selection
