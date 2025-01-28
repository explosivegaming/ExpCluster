local Gui = require("modules/exp_gui")
local ExpElement = require("modules/exp_gui/prototype")
local PlayerData = require("modules.exp_legacy.expcore.player_data") --- @dep expcore.player_data

-- Used to store the state of the toolbar when a player leaves
local ToolbarState = PlayerData.Settings:combine("ToolbarState")
ToolbarState:set_metadata{
    stringify = function(value)
        local buttons, favourites = 0, 0
        for _, state in ipairs(value) do
            buttons = buttons + 1
            if state.favourite then
                favourites = favourites + 1
            end
        end

        return string.format("Buttons: %d, Favourites: %d", buttons, favourites)
    end,
}

--- Set the default value for the datastore
local datastore_id_map = {} --- @type table<string, ExpElement>
local toolbar_default_state = {}
ToolbarState:set_default(toolbar_default_state)

--- Get the datastore id for this element define, to best of ability it should be unique between versions
local function to_datastore_id(element_define)
    -- First try to use the tooltip locale string
    local tooltip = element_define.tooltip
    if type(tooltip) == "table" then
        return tooltip[1]:gsub("%.(.+)", "")
    end

    -- Then try to use the caption or sprite
    return element_define.caption or element_define.sprite
end

--- For all top element, register an on click which will copy their style
for index, element_define in ipairs(Gui.top_elements) do
    -- Insert the element into the id map
    datastore_id_map[to_datastore_id(element_define)] = element_define -- Backwards Compatibility
    datastore_id_map[element_define.name] = element_define

    -- Add the element to the default state
    table.insert(toolbar_default_state, {
        element = element_define.uid,
        favourite = true,
    })
end

--- Get the top order based on the players settings
Gui.inject_top_flow_order(function(player)
    local order = ToolbarState:get(player)

    local elements = {}
    for index, state in ipairs(order) do
        elements[index] = Gui.defines[state.element]
    end

    return elements
end)

--- Get the left order based on the player settings, with toolbar menu first, and all remaining after
Gui.inject_left_flow_order(function(player)
    local order = Gui.get_top_flow_order(player)
    local elements, element_map = { toolbar_container }, { [toolbar_container] = true }

    -- Add the flows that have a top element
    for _, element_define in ipairs(order) do
        if element_define.left_flow_element then
            table.insert(elements, element_define.left_flow_element)
            element_map[element_define.left_flow_element] = true
        end
    end

    -- Add the flows that dont have a top element
    for _, element_define in ipairs(Gui.left_elements) do
        if not element_map[element_define] then
            table.insert(elements, element_define)
        end
    end

    return elements
end)

--- Overwrite the default update top flow
local _update_top_flow = Gui.update_top_flow
function Gui.update_top_flow(player)
    _update_top_flow(player) -- Call the original

    local order = ToolbarState:get(player)
    for index, state in ipairs(order) do
        local element_define = Gui.defines[state.element]
        local top_element = Gui.get_top_element(player, element_define)
        top_element.visible = top_element.visible and state.favourite or false
    end
end

--- Uncompress the data to be more useable
ToolbarState:on_load(function(player_name, value)
    -- If there is no value, do nothing
    if value == nil then return end
    --- @cast value [ string[], string[], string[], boolean ]

    -- Create a hash map of the favourites
    local favourites = {}
    for _, id in ipairs(value[2]) do
        favourites[id] = true
    end

    -- Read the order from the value
    local elements = {}
    local element_hash = {}
    for index, id in ipairs(value[1]) do
        local element = datastore_id_map[id]
        if element and not element_hash[element.name] then
            element_hash[element.name] = true
            elements[index] = {
                element = element,
                favourite = favourites[id] or false,
            }
        end
    end

    -- Add any in the default state that are missing
    for _, state in ipairs(toolbar_default_state) do
        if not element_hash[state.element] then
            table.insert(elements, table.deep_copy(state))
        end
    end

    -- Create a hash map of the open left flows
    local open_left_elements = {}
    for _, id in ipairs(value[3]) do
        local element = datastore_id_map[id]
        local left_element = element.left_flow_element
        if left_element then
            open_left_elements[left_element] = true
        end
    end

    -- Set the visible state of all left flows
    local player = assert(game.get_player(player_name))
    for left_element in pairs(Gui.left_elements) do
        Gui.set_left_element_visible(left_element, player, open_left_elements[left_element] or false)
    end

    -- Set the toolbar visible state
    Gui.set_top_flow_visible(player, value[4])

    -- Set the data now and update now, ideally this would be on_update but that had too large of a latency
    ToolbarState:raw_set(player_name, elements)
    Gui.reorder_top_flow(player)
    Gui.reorder_left_flow(player)
    reorder_toolbar_menu(player)

    return elements
end)

--- Save the current state of the players toolbar menu
ToolbarState:on_save(function(player_name, value)
    if value == nil then return nil end -- Don't save default
    local order, favourites, left_flows = {}, {}, {}

    local player = assert(game.get_player(player_name))
    local top_flow_open = Gui.get_top_flow(player).parent.visible

    for index, state in ipairs(value) do
        -- Add the element to the order array
        --- @diagnostic disable-next-line invisible
        local element_define = ExpElement._elements[state.element]
        local id = to_datastore_id(element_define)
        order[index] = id

        -- If its a favourite then insert it
        if state.favourite then
            table.insert(favourites, id)
        end

        -- If it has a left flow and its open then insert it
        if element_define.left_flow_element then
            local left_element = Gui.get_left_element(element_define.left_flow_element, player)
            if left_element.visible then
                table.insert(left_flows, id)
            end
        end
    end

    return { order, favourites, left_flows, top_flow_open }
end)
