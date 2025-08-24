
local Storage = require("modules/exp_util/storage")

local ExpElement = require("modules/exp_gui/prototype")

--- @alias Gui.VisibleCallback fun(player: LuaPlayer, element: LuaGuiElement): boolean

--- @class Gui.player_elements
--- @field top table<string, LuaGuiElement?>
--- @field left table<string, LuaGuiElement?>
--- @field relative table<string, LuaGuiElement?>

--- @type table<uint, Gui.player_elements> | table<"_debug", boolean>
local player_elements = {}
Storage.register(player_elements, function(tbl)
    player_elements = tbl
end)

--- @class Gui
local Gui = {
    define = ExpElement.new,
    from_argument = ExpElement.from_argument,
    from_name = ExpElement.from_name,
    no_return = ExpElement.no_return,
    top_elements = {}, --- @type table<ExpElement, Gui.VisibleCallback | boolean>
    left_elements = {}, --- @type table<ExpElement, Gui.VisibleCallback | boolean>
    relative_elements = {}, --- @type table<ExpElement, Gui.VisibleCallback | boolean>
}

local mod_gui = require("mod-gui")
Gui.get_top_flow = mod_gui.get_button_flow
Gui.get_left_flow = mod_gui.get_frame_flow

--- Set the gui to redraw all elements on join, helps with style debugging
--- @param state boolean
function Gui._debug(state)
    if state == nil then
        player_elements._debug = true
    else
        player_elements._debug = state
    end
end

--- Get a player from an element or gui event
--- @param input LuaGuiElement | { player_index: uint } | { element: LuaGuiElement }
--- @return LuaPlayer
function Gui.get_player(input)
    if type(input) == "table" and not input.player_index then
        return assert(game.get_player(input.element.player_index))
    end
    return assert(game.get_player(input.player_index))
end

--- Toggle the enable state of an element
--- @param element LuaGuiElement
--- @param state boolean?
--- @return boolean
function Gui.toggle_enabled_state(element, state)
    if not element or not element.valid then return false end
    if state == nil then
        state = not element.enabled
    end
    element.enabled = state
    return state
end

--- Toggle the visibility of an element
--- @param element LuaGuiElement
--- @param state boolean?
--- @return boolean
function Gui.toggle_visible_state(element, state)
    if not element or not element.valid then return false end
    if state == nil then
        state = not element.visible
    end
    element.visible = state
    return state
end

--- Destroy an element if it exists and is valid
--- @param element LuaGuiElement?
function Gui.destroy_if_valid(element)
    if not element or not element.valid then return end
    element.destroy()
end

--- Register a element define to be drawn to the top flow on join
--- @param define ExpElement
--- @param visible Gui.VisibleCallback | boolean | nil
function Gui.add_top_element(define, visible)
    assert(Gui.top_elements[define.name] == nil, "Element is already added to the top flow")
    Gui.top_elements[define] = visible or false
end

--- Register a element define to be drawn to the left flow on join
--- @param define ExpElement
--- @param visible Gui.VisibleCallback | boolean | nil
function Gui.add_left_element(define, visible)
    assert(Gui.left_elements[define.name] == nil, "Element is already added to the left flow")
    Gui.left_elements[define] = visible or false

end

--- Register a element define to be drawn to the relative flow on join
--- @param define ExpElement
--- @param visible Gui.VisibleCallback | boolean | nil
function Gui.add_relative_element(define, visible)
    assert(Gui.relative_elements[define.name] == nil, "Element is already added to the relative flow")
    Gui.relative_elements[define] = visible or false
end

--- Register a element define to be drawn to the top flow on join
--- @param define ExpElement
--- @param player LuaPlayer
--- @return LuaGuiElement
function Gui.get_top_element(define, player)
    return assert(player_elements[player.index].top[define.name], "Element is not on the top flow")
end

--- Register a element define to be drawn to the left flow on join
--- @param define ExpElement
--- @param player LuaPlayer
--- @return LuaGuiElement
function Gui.get_left_element(define, player)
    return assert(player_elements[player.index].left[define.name], "Element is not on the left flow")
end

--- Register a element define to be drawn to the relative flow on join
--- @param define ExpElement
--- @param player LuaPlayer
--- @return LuaGuiElement
function Gui.get_relative_element(define, player)
    return assert(player_elements[player.index].relative[define.name], "Element is not on the relative flow")
end

--- Ensure all the correct elements are visible and exist
--- @param player LuaPlayer
--- @param element_defines table<ExpElement, Gui.VisibleCallback | boolean>
--- @param elements table<string, LuaGuiElement?>
--- @param parent LuaGuiElement
local function ensure_elements(player, element_defines, elements, parent)
    local done = {}
    for define, visible in pairs(element_defines) do
        done[define.name] = true
        local element = elements[define.name]
        if not element or not element.valid then
            element = assert(define(parent), "Element define did not return an element: " .. define.name)
            elements[define.name] = element

            if type(visible) == "function" then
                visible = visible(player, element)
            end
            element.visible = visible
        end
    end

    for name, element in pairs(elements) do
        if not done[name] then
            element.destroy()
            elements[name] = nil
        end
    end
end

--- Ensure all elements have been created
--- @param event EventData.on_player_created | EventData.on_player_joined_game
function Gui._ensure_consistency(event)
    local player = assert(game.get_player(event.player_index))
    local elements = player_elements[event.player_index] or {
        top = {},
        left = {},
        relative = {},
    }
    player_elements[event.player_index] = elements

    if player_elements._debug and event.name == defines.events.on_player_joined_game then
        log("Gui debug active, clearing gui for: " .. player.name)
        player.gui.relative.clear()
        player.gui.screen.clear()
        player.gui.center.clear()
        player.gui.left.clear()
        player.gui.top.clear()
    end

    ensure_elements(player, Gui.top_elements, elements.top, Gui.get_top_flow(player))
    ensure_elements(player, Gui.left_elements, elements.left, Gui.get_left_flow(player))
    ensure_elements(player, Gui.relative_elements, elements.relative, player.gui.relative)

    -- This check isn't needed, but allows the toolbar file to be deleted without modifying any lib code
    if Gui.toolbar then
        --- @diagnostic disable-next-line invisible
        Gui.toolbar._create_elements(player)
        --- @diagnostic disable-next-line invisible
        Gui.toolbar._ensure_consistency(player)
    end
end

--- Rerun the visible check for relative elements
--- @param event EventData.on_gui_opened
local function on_gui_opened(event)
    local player = Gui.get_player(event)
    local original_element = event.element

    for define, visible in pairs(Gui.relative_elements) do
        local element = Gui.get_relative_element(define, player)

        if type(visible) == "function" then
            visible = visible(player, element)
        end
        element.visible = visible

        if visible then
            event.element = element
            --- @diagnostic disable-next-line invisible
            define:raise_event(event)
        end
    end

    event.element = original_element
end

local e = defines.events
local events = {
    [e.on_player_created] = Gui._ensure_consistency,
    [e.on_player_joined_game] = Gui._ensure_consistency,
    [e.on_gui_opened] = on_gui_opened,
}

Gui.events = events
return Gui
