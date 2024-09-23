--[[-- Control Module - Selection
    - Controls players who have a selection planner, mostly event handlers
    @control Selection
    @alias Selection
]]

local Event = require 'utils.event' --- @dep utils.event
local Global = require 'utils.global' --- @dep utils.global
local Selection = {
    events = {
        --- When a player enters selection mode
        -- @event on_player_selection_start
        -- @tparam number player_index the player index of the player who entered selection mode
        -- @tparam string selection the name of the selection being made
        on_player_selection_start = script.generate_event_name(),
        --- When a player leaves selection mode
        -- @event on_player_selection_end
        -- @tparam number player_index the player index of the player who left selection mode
        -- @tparam string selection the name of the selection which ended
        on_player_selection_end = script.generate_event_name(),
    }
}

local selection_tool = { name='selection-tool' }

local selections = {}
Global.register({
    selections = selections
}, function(tbl)
    selections = tbl.selections
end)

--- Let a player select an area by providing a selection planner
-- @tparam LuaPlayer player The player to place into selection mode
-- @tparam string selection_name The name of the selection to start, used with on_selection
-- @tparam[opt=false] boolean single_use When true the selection will stop after first use
function Selection.start(player, selection_name, single_use, ...)
    if not player or not player.valid then return end
    if selections[player.index] then
        -- Raise the end event if a selection was already in progress
        script.raise_event(Selection.events.on_player_selection_end, {
            name = Selection.events.on_player_selection_end,
            tick = game.tick,
            player_index = player.index,
            selection = selections[player.index].name
        })
    end

    -- Set the selection data
    selections[player.index] = {
        name = selection_name,
        arguments = { ... },
        single_use = single_use == true,
        character = player.character
    }

    -- Raise the event
    script.raise_event(Selection.events.on_player_selection_start, {
        name = Selection.events.on_player_selection_start,
        tick = game.tick,
        player_index = player.index,
        selection = selection_name
    })

    -- Give a selection tool if one is not in use
    if player.cursor_stack.is_selection_tool then return end
    player.clear_cursor() -- Clear the current item
    player.cursor_stack.set_stack(selection_tool)

    -- Make a slot to place the selection tool even if inventory is full
    if not player.character then return end
    player.character_inventory_slots_bonus = player.character_inventory_slots_bonus + 1
    player.hand_location = { inventory = defines.inventory.character_main, slot = #player.get_main_inventory() }
end

--- Stop a player selection by removing the selection planner
-- @tparam LuaPlayer player The player to exit out of selection mode
function Selection.stop(player)
    if not selections[player.index] then return end
    local character = selections[player.index].character
    local selection = selections[player.index].name
    selections[player.index] = nil

    -- Raise the event
    script.raise_event(Selection.events.on_player_selection_end, {
        name = Selection.events.on_player_selection_end,
        tick = game.tick,
        player_index = player.index,
        selection = selection
    })

    -- Remove the selection tool
    if player.cursor_stack.is_selection_tool then
        player.cursor_stack.clear()
    else
        player.remove_item(selection_tool)
    end

    -- Remove the extra slot
    if character and character == player.character then
        player.character_inventory_slots_bonus = player.character_inventory_slots_bonus - 1
        player.hand_location = nil
    end
end

--- Get the selection arguments for a player
-- @tparam LuaPlayer player The player to get the selection arguments for
function Selection.get_arguments(player)
    if not selections[player.index] then return end
    return selections[player.index].arguments
end

--- Test if a player is selecting something
-- @tparam LuaPlayer player The player to test
-- @tparam[opt] string selection_name If given will only return true if the selection is this selection
function Selection.is_selecting(player, selection_name)
    if selection_name ~= nil then
        if not selections[player.index] then return false end
        return selections[player.index].name == selection_name
    else
        return player.cursor_stack.is_selection_tool
    end
end

--- Filter on_player_selected_area to this custom selection, appends the selection arguments
-- @tparam string selection_name The name of the selection to listen for
-- @tparam function handler The event handler
function Selection.on_selection(selection_name, handler)
    Event.add(defines.events.on_player_selected_area, function(event)
        local selection = selections[event.player_index]
        if not selection or selection.name ~= selection_name then return end
        handler(event, table.unpack(selection.arguments))
    end)
end

--- Filter on_player_alt_selected_area to this custom selection, appends the selection arguments
-- @param string selection_name The name of the selection to listen for
-- @param function handler The event handler
function Selection.on_alt_selection(selection_name, handler)
    Event.add(defines.events.on_player_alt_selected_area, function(event)
        local selection = selections[event.player_index]
        if not selection or selection.name ~= selection_name then return end
        handler(event, table.unpack(selection.arguments))
    end)
end

--- Stop selection if the selection tool is removed from the cursor
Event.add(defines.events.on_player_cursor_stack_changed, function(event)
    local player = game.get_player(event.player_index) ---@cast player -nil
    if player.cursor_stack.is_selection_tool then return end
    Selection.stop(player)
end)
--- Stop selection after an event such as death or leaving the game
local function stop_after_event(event)
    local player = game.get_player(event.player_index)
    Selection.stop(player)
end

Event.add(defines.events.on_pre_player_left_game, stop_after_event)
Event.add(defines.events.on_pre_player_died, stop_after_event)

--- Stop selection after a single use if single_use was true during Selection.start
local function stop_after_use(event)
    if not selections[event.player_index] then return end
    if not selections[event.player_index].single_use then return end
    stop_after_event(event)
end

Event.add(defines.events.on_player_selected_area, stop_after_use)
Event.add(defines.events.on_player_alt_selected_area, stop_after_use)

return Selection