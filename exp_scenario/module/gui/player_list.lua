--[[-- Gui - Player List
Adds a player list to show names and play time; also includes action buttons which can perform actions on players.
The selected player and action used to be stored in a datastore; they are now kept on the container's player data.
]]

local ExpUtil = require("modules/exp_util")
local Gui = require("modules/exp_gui")
local Roles = require("modules/exp_legacy/expcore/roles")
local config = require("modules/exp_legacy/config/gui/player_list_actions")

--- @class ExpGui_PlayerList.elements
local Elements = {}

local online_time_format = ExpUtil.format_time_factory_locale{ format = "short", hours = true, minutes = true }
local afk_time_format = ExpUtil.format_time_factory_locale{ format = "long", minutes = true }

--[[
The selected player (the player an action will be performed on) and the selected action (which opens the reason bar)
are stored per viewing player on the container's player data. The setters drive the gui updates directly, replacing
the reactive datastore on_update callbacks used by the legacy version.
]]

--- @class ExpGui_PlayerList.selection
--- @field selected_player string? Name of the player actions will be performed on
--- @field selected_action string? Name of the action awaiting a reason

--- Get the selection state for a player, creating it if needed
--- @param player LuaPlayer
--- @return ExpGui_PlayerList.selection
local function get_selection(player)
    local selection = Elements.container.data[player]
    if not selection then
        selection = {}
        Elements.container.data[player] = selection
    end
    return selection
end

--- Get the name of the player that actions will be performed on
--- @param player LuaPlayer
--- @return string?
local function get_selected_player(player)
    return get_selection(player).selected_player
end

--- Get the name of the action awaiting a reason
--- @param player LuaPlayer
--- @return string?
local function get_selected_action(player)
    return get_selection(player).selected_action
end

--- Style an open action bar button to show if it is the selected player
--- @param button LuaGuiElement
--- @param selected boolean
local function style_open_button(button, selected)
    button.style = selected and "tool_button" or "frame_button"
    local style = button.style
    style.padding = -2
    style.width = 8
    style.height = 14
end

--- Update the action bar buttons to match the current selection for a player
--- @param action_bar LuaGuiElement
--- @param player LuaPlayer
--- @param selected_player LuaPlayer
local function update_action_bar(action_bar, player, selected_player)
    action_bar.visible = true
    for action_name, buttons in pairs(config.buttons) do
        local flow = action_bar[action_name]
        if buttons.auth and not buttons.auth(player, selected_player) then
            flow.visible = false
        else
            flow.visible = Roles.player_allowed(player, action_name)
        end
    end
end

--- Refresh all gui elements for a player to match their current selection
--- @param player LuaPlayer
local function update_player_ui(player)
    local selection = get_selection(player)

    -- Clear the selection if the selected player has gone offline
    local selected_player = selection.selected_player and game.players[selection.selected_player]
    if selected_player and not selected_player.connected then
        selection.selected_player = nil
        selection.selected_action = nil
        selected_player = nil
    end

    for _, player_table in Elements.player_table:online_elements(player) do
        local refs = Elements.player_table.data[player_table]

        -- Update the action bar and reason bar visibility
        if selected_player then
            update_action_bar(refs.action_bar, player, selected_player)
        else
            refs.action_bar.visible = false
        end
        refs.reason_bar.visible = selected_player ~= nil and selection.selected_action ~= nil

        -- Highlight the open button of the selected player
        for player_name, row in pairs(refs.rows) do
            style_open_button(row.open_button, player_name == selection.selected_player)
        end
    end
end

--- Set the player that actions will be performed on, nil to clear the selection
--- @param player LuaPlayer
--- @param selected_player_name string?
local function set_selected_player(player, selected_player_name)
    local selection = get_selection(player)
    selection.selected_player = selected_player_name
    if not selected_player_name then
        selection.selected_action = nil
    end
    update_player_ui(player)
end

--- Toggle the player that actions will be performed on
--- @param player LuaPlayer
--- @param selected_player_name string
local function toggle_selected_player(player, selected_player_name)
    if get_selected_player(player) == selected_player_name then
        set_selected_player(player, nil)
    else
        set_selected_player(player, selected_player_name)
    end
end

--- Set the action awaiting a reason, nil to clear it
--- @param player LuaPlayer
--- @param selected_action string?
local function set_selected_action(player, selected_action)
    get_selection(player).selected_action = selected_action
    update_player_ui(player)
end

-- Inject the accessors the actions config needs to read the selected player and set the selected action
config.set_accessors(get_selected_player, set_selected_action)

--- Button used to open the action bar for a player
--- @class ExpGui_PlayerList.elements.open_action_bar: ExpElement
--- @field data table<LuaGuiElement, string>
--- @overload fun(parent: LuaGuiElement, player_name: string): LuaGuiElement
Elements.open_action_bar = Gui.define("player_list/open_action_bar")
    :draw{
        type = "sprite-button",
        sprite = "utility/expand_dots",
        tooltip = { "exp-gui_player-list.open-action-bar" },
        style = "frame_button",
    }
    :style{
        padding = -2,
        width = 8,
        height = 14,
    }
    :element_data(
        Gui.from_argument(1)
    )
    :on_click(function(def, player, element)
        --- @cast def ExpGui_PlayerList.elements.open_action_bar
        toggle_selected_player(player, def.data[element])
    end) --[[ @as any ]]

--- Button used to close the action bar
--- @class ExpGui_PlayerList.elements.close_action_bar: ExpElement
--- @overload fun(parent: LuaGuiElement): LuaGuiElement
Elements.close_action_bar = Gui.define("player_list/close_action_bar")
    :draw{
        type = "sprite-button",
        sprite = "utility/close_black",
        tooltip = { "exp-gui_player-list.close-action-bar" },
        style = "slot_sized_button_red",
    }
    :style(Gui.styles.sprite{
        size = 20,
        padding = -1,
        top_margin = -1,
        right_margin = -1,
    })
    :on_click(function(def, player, element)
        set_selected_player(player, nil)
    end) --[[ @as any ]]

--- Button used to confirm a reason
--- @class ExpGui_PlayerList.elements.reason_confirm: ExpElement
--- @overload fun(parent: LuaGuiElement): LuaGuiElement
Elements.reason_confirm = Gui.define("player_list/reason_confirm")
    :draw{
        type = "sprite-button",
        sprite = "utility/confirm_slot",
        tooltip = { "exp-gui_player-list.reason-confirm" },
        style = "slot_sized_button_green",
    }
    :style(Gui.styles.sprite{
        size = 30,
        padding = -1,
        left_margin = -2,
        right_margin = -1,
    })
    :on_click(function(def, player, element)
        local action_name = get_selected_action(player)
        local button_data = action_name and config.buttons[action_name]
        if button_data and button_data.reason_callback then
            local reason = element.parent.entry.text
            if reason == nil or not reason:find("%S") then reason = "no reason given" end
            button_data.reason_callback(player, reason)
        end
        element.parent.entry.text = ""
        set_selected_player(player, nil)
    end) --[[ @as any ]]

--- Clickable player name label, left click opens the map and right click toggles the action bar
--- @class ExpGui_PlayerList.elements.player_name_label: ExpElement
--- @field data table<LuaGuiElement, string>
--- @overload fun(parent: LuaGuiElement, opts: { name: string, tooltip: LocalisedString }): LuaGuiElement
Elements.player_name_label = Gui.define("player_list/player_name_label")
    :draw{
        type = "label",
        caption = Gui.from_argument("name"),
        tooltip = Gui.from_argument("tooltip"),
    }
    :style{
        padding = { 0, 2, 0, 0 },
    }
    :element_data(
        Gui.from_argument("name")
    )
    :on_click(function(def, player, element, event)
        --- @cast def ExpGui_PlayerList.elements.player_name_label
        local selected_player_name = def.data[element]
        local selected_player = game.players[selected_player_name]
        if event.button == defines.mouse_button_type.left then
            -- Left click opens remote view at the player
            player.set_controller{
                type = defines.controllers.remote,
                position = selected_player.physical_position,
                surface = selected_player.physical_surface,
            }
        else
            -- Right click toggles the action bar
            toggle_selected_player(player, selected_player_name)
        end
    end) --[[ @as any ]]

--- @class ExpGui_PlayerList.player_data
--- @field name string
--- @field tag string
--- @field role_name string
--- @field chat_color Color
--- @field caption LocalisedString
--- @field tooltip LocalisedString

--- Get the caption and tooltip for a player time
--- @param online_time number
--- @param afk_time number
--- @return LocalisedString, LocalisedString
local function get_time_formats(online_time, afk_time)
    local tick = game.tick > 0 and game.tick or 1
    local percent = math.round(online_time / tick, 3) * 100
    local caption = online_time_format(online_time)
    local tooltip = { "exp-gui_player-list.afk-time", percent, afk_time_format(afk_time) }
    return caption, tooltip
end

--- Get a list of all online players sorted by their highest role
--- @return ExpGui_PlayerList.player_data[]
local function get_player_list_order()
    -- Sort all the online players into roles
    local players = {}
    for _, player in pairs(game.connected_players) do
        local highest_role = Roles.get_player_highest_role(player)
        if not players[highest_role.name] then
            players[highest_role.name] = {}
        end
        table.insert(players[highest_role.name], player)
    end

    -- Flatten the roles into a single ordered list
    local count = 0
    local player_list_order = {}
    for _, role_name in pairs(Roles.config.order) do
        if players[role_name] then
            for _, player in pairs(players[role_name]) do
                count = count + 1
                local caption, tooltip = get_time_formats(player.online_time, player.afk_time)
                player_list_order[count] = {
                    name = player.name,
                    tag = player.tag,
                    role_name = role_name,
                    chat_color = player.chat_color,
                    caption = caption,
                    tooltip = tooltip,
                }
            end
        end
    end

    return player_list_order
end

--- @class ExpGui_PlayerList.elements.player_table.row
--- @field open_button LuaGuiElement
--- @field name_label LuaGuiElement
--- @field time_label LuaGuiElement

--- @class ExpGui_PlayerList.elements.player_table.data
--- @field rows table<string, ExpGui_PlayerList.elements.player_table.row>
--- @field action_bar LuaGuiElement
--- @field reason_bar LuaGuiElement

--- Scroll table containing a row for each online player
--- @class ExpGui_PlayerList.elements.player_table: ExpElement
--- @field data table<LuaGuiElement, ExpGui_PlayerList.elements.player_table.data>
--- @overload fun(parent: LuaGuiElement): LuaGuiElement
Elements.player_table = Gui.define("player_list/player_table")
    :track_all_elements()
    :draw(function(def, parent)
        local scroll_table = Gui.elements.scroll_table(parent, 184, 3, "scroll")
        scroll_table.style.padding = { 1, 0, 1, 2 }
        return scroll_table
    end) --[[ @as any ]]

--- Add a player row to the table and store its elements
--- @param player_table LuaGuiElement
--- @param player_data ExpGui_PlayerList.player_data
function Elements.player_table.add_row(player_table, player_data)
    local rows = Elements.player_table.data[player_table].rows

    -- Add the button used to open the action bar
    local open_flow = player_table.add{ type = "flow" }
    local open_button = Elements.open_action_bar(open_flow, player_data.name)

    -- Add the clickable player name
    local name_label = Elements.player_name_label(player_table, {
        name = player_data.name,
        tooltip = { "exp-gui_player-list.open-map", player_data.name, player_data.tag, player_data.role_name },
    })
    name_label.style.font_color = player_data.chat_color

    -- Add the time played label
    local alignment = Gui.elements.aligned_flow(player_table)
    local time_label = alignment.add{
        type = "label",
        caption = player_data.caption,
        tooltip = player_data.tooltip,
    }
    time_label.style.padding = 0

    rows[player_data.name] = { open_button = open_button, name_label = name_label, time_label = time_label }
end

--- Rebuild all rows of a player table, used when the sort order changes
--- @param player_table LuaGuiElement
function Elements.player_table.rebuild(player_table)
    player_table.clear()
    Elements.player_table.data[player_table].rows = {}
    for _, player_data in ipairs(get_player_list_order()) do
        Elements.player_table.add_row(player_table, player_data)
    end
end

--- Remove a single player row from the table
--- @param player_table LuaGuiElement
--- @param player_name string
function Elements.player_table.remove_row(player_table, player_name)
    local rows = Elements.player_table.data[player_table].rows
    local row = rows[player_name]
    if not row then return end
    rows[player_name] = nil
    Gui.destroy_if_valid(row.open_button.parent)
    Gui.destroy_if_valid(row.name_label)
    Gui.destroy_if_valid(row.time_label.parent)
end

--- Refresh the time labels for all rows of a player table
--- @param player_table LuaGuiElement
function Elements.player_table.refresh_times(player_table)
    for player_name, row in pairs(Elements.player_table.data[player_table].rows) do
        local listed_player = game.players[player_name]
        if listed_player and listed_player.connected then
            local caption, tooltip = get_time_formats(listed_player.online_time, listed_player.afk_time)
            row.time_label.caption = caption
            row.time_label.tooltip = tooltip
        end
    end
end

--- Build the action bar footer containing the close button and the per action button flows
--- @param container LuaGuiElement
--- @return LuaGuiElement
local function build_action_bar(container)
    local action_bar = Gui.elements.subframe_base(container, "subfooter_frame", "action_bar")
    local style = action_bar.style
    style.height = 35
    style.padding = { 1, 3 }
    action_bar.visible = false

    Elements.close_action_bar(action_bar)
    for action_name, button_data in pairs(config.buttons) do
        local permission_flow = action_bar.add{ type = "flow", name = action_name }
        permission_flow.visible = false
        for _, button in ipairs(button_data) do
            button(permission_flow)
        end
    end

    return action_bar
end

--- Build the reason bar footer containing the reason entry and confirm button
--- @param container LuaGuiElement
--- @return LuaGuiElement
local function build_reason_bar(container)
    local reason_bar = Gui.elements.subframe_base(container, "subfooter_frame", "reason_bar")
    local style = reason_bar.style
    style.height = 35
    style.padding = { -1, 3 }
    reason_bar.visible = false

    local reason_field = reason_bar.add{
        name = "entry",
        type = "textfield",
        style = "stretchable_textfield",
        tooltip = { "exp-gui_player-list.reason-entry" },
    }
    local entry_style = reason_field.style
    entry_style.padding = 0
    entry_style.height = 28
    entry_style.minimal_width = 160

    Elements.reason_confirm(reason_bar)

    return reason_bar
end

--- Container added to the left gui flow
--- @class ExpGui_PlayerList.elements.container: ExpElement
--- @field data table<LuaPlayer, ExpGui_PlayerList.selection>
Elements.container = Gui.define("player_list/container")
    :draw(function(def, parent)
        local container = Gui.elements.container(parent)

        local player = Gui.get_player(parent)
        def.data[player] = def.data[player] or {} -- Selection state for this player

        local player_table = Elements.player_table(container)
        local action_bar = build_action_bar(container)
        local reason_bar = build_reason_bar(container)

        Elements.player_table.data[player_table] = {
            rows = {},
            action_bar = action_bar,
            reason_bar = reason_bar,
        }
        Elements.player_table.rebuild(player_table)

        return Gui.elements.container.get_root_element(container)
    end) --[[ @as any ]]

--- Add the element to the left flow with a toolbar button
Gui.add_left_element(Elements.container, true)
Gui.toolbar.create_button{
    name = "toggle_player_list",
    left_element = Elements.container,
    sprite = "entity/character",
    tooltip = { "exp-gui_player-list.main-tooltip" },
    visible = function(player, element)
        return Roles.player_allowed(player, "gui/player-list")
    end
}

--- Refresh the play times for all online players
local function refresh_times()
    for _, player_table in Elements.player_table:online_elements() do
        Elements.player_table.refresh_times(player_table)
    end
end

--- Rebuild the player list for all online players, used when the sort order changes
local function redraw_player_list()
    for _, player_table in Elements.player_table:online_elements() do
        Elements.player_table.rebuild(player_table)
        update_player_ui(Gui.get_player(player_table))
    end
end

--- Remove a player from the list when they leave and clear any selection pointing at them
--- @param event EventData.on_player_left_game
local function on_player_left_game(event)
    local left_player = game.players[event.player_index]
    for _, player_table in Elements.player_table:online_elements() do
        Elements.player_table.remove_row(player_table, left_player.name)
        local viewing_player = Gui.get_player(player_table)
        if get_selected_player(viewing_player) == left_player.name then
            set_selected_player(viewing_player, nil)
        end
    end
end

local e = defines.events

return {
    elements = Elements,
    events = {
        [e.on_player_joined_game] = redraw_player_list,
        [e.on_player_left_game] = on_player_left_game,
        [Roles.events.on_role_assigned] = redraw_player_list,
        [Roles.events.on_role_unassigned] = redraw_player_list,
    },
    on_nth_tick = {
        [1800] = refresh_times,
    }
}
