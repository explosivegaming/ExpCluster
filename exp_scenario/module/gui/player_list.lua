--[[-- Gui - Player List
Adds a player list to show names and play time; also includes action buttons which can perform actions on players.
]]

local ExpUtil = require("modules/exp_util")
local Gui = require("modules/exp_gui")
local Roles = require("modules/exp_legacy/expcore/roles")
local config = require("modules/exp_legacy/config/gui/player_list_actions")

--- @class ExpGui_PlayerList.elements
local Elements = {}

local online_time_format = ExpUtil.format_time_factory_locale{ format = "short", hours = true, minutes = true }
local afk_time_format = ExpUtil.format_time_factory_locale{ format = "long", minutes = true }

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

--- Button used to open the action bar for a player
--- @class ExpGui_PlayerList.elements.open_action_bar: ExpElement
--- @field data table<LuaGuiElement, LuaPlayer>
--- @overload fun(parent: LuaGuiElement, selected_player: LuaPlayer): LuaGuiElement
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
        Elements.container.toggle_selected_player(player, def.data[element])
        Elements.player_table.refresh_player(player)
    end) --[[ @as any ]]

--- Set whether an open action bar button shows as highlighted
--- @param open_button LuaGuiElement
--- @param highlighted boolean
function Elements.open_action_bar.set_highlight(open_button, highlighted)
    open_button.style = highlighted and "tool_button" or "frame_button"
    local style = open_button.style
    style.padding = -2
    style.width = 8
    style.height = 14
end

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
    :style{
        size = 30,
        padding = -1,
        top_margin = -1,
        right_margin = -1,
    }
    :on_click(function(_, player)
        Elements.container.set_selected_player(player, nil)
        Elements.player_table.refresh_player(player)
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
    :style{
        size = 30,
        padding = -1,
        left_margin = -2,
        right_margin = -1,
    }
    :on_click(function(_, player, element)
        local action_name = Elements.container.get_selected_action(player)
        local button_data = action_name and config.buttons[action_name]
        if button_data and button_data.reason_callback then
            local reason = element.parent.entry.text
            if reason == nil or not reason:find("%S") then reason = "no reason given" end
            button_data.reason_callback(player, reason)
        end
        element.parent.entry.text = ""
        Elements.container.set_selected_player(player, nil)
        Elements.player_table.refresh_player(player)
    end) --[[ @as any ]]

--- Clickable player name label, left click opens the map and right click toggles the action bar
--- @class ExpGui_PlayerList.elements.player_name_label: ExpElement
--- @field data table<LuaGuiElement, LuaPlayer>
--- @overload fun(parent: LuaGuiElement, opts: { name: string, player: LuaPlayer, tooltip: LocalisedString }): LuaGuiElement
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
        Gui.from_argument("player")
    )
    :on_click(function(def, player, element, event)
        --- @cast def ExpGui_PlayerList.elements.player_name_label
        local selected_player = def.data[element]
        if event.button == defines.mouse_button_type.left then
            -- Left click opens remote view at the player
            player.set_controller{
                type = defines.controllers.remote,
                position = selected_player.physical_position,
                surface = selected_player.physical_surface,
            }
        else
            -- Right click toggles the action bar
            Elements.container.toggle_selected_player(player, selected_player)
            Elements.player_table.refresh_player(player)
        end
    end) --[[ @as any ]]

--- @class ExpGui_PlayerList.elements.player_table.row
--- @field open_button LuaGuiElement
--- @field name_label LuaGuiElement
--- @field time_label LuaGuiElement

--- @class ExpGui_PlayerList.elements.player_table.element_data
--- @field rows table<string, ExpGui_PlayerList.elements.player_table.row>
--- @field action_bar LuaGuiElement
--- @field reason_bar LuaGuiElement

--- Scroll table containing a row for each online player
--- @class ExpGui_PlayerList.elements.player_table: ExpElement
--- @field data table<LuaGuiElement, ExpGui_PlayerList.elements.player_table.element_data>
--- @overload fun(parent: LuaGuiElement): LuaGuiElement
Elements.player_table = Gui.define("player_list/player_table")
    :track_all_elements()
    :draw(function(_, parent)
        return Gui.elements.scroll_table(parent, 184, 3, "scroll")
    end)
    :style{
        padding = { 1, 0, 1, 2 },
    } --[[ @as any ]]

--- Store the action and reason bars associated with a player table
--- @param player_table LuaGuiElement
--- @param action_bar LuaGuiElement
--- @param reason_bar LuaGuiElement
function Elements.player_table.set_bars(player_table, action_bar, reason_bar)
    Elements.player_table.data[player_table] = {
        rows = {},
        action_bar = action_bar,
        reason_bar = reason_bar,
    }
end

--- @class ExpGui_PlayerList.elements.player_table.row_data
--- @field player LuaPlayer
--- @field tag string
--- @field role_name string
--- @field chat_color Color
--- @field caption LocalisedString
--- @field tooltip LocalisedString

--- Calculate the ordered list of online players sorted by their highest role
--- @return ExpGui_PlayerList.elements.player_table.row_data[]
function Elements.player_table.calculate_row_data()
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
    local row_data = {}
    for _, role_name in pairs(Roles.config.order) do
        if players[role_name] then
            for _, player in pairs(players[role_name]) do
                count = count + 1
                local caption, tooltip = get_time_formats(player.online_time, player.afk_time)
                row_data[count] = {
                    player = player,
                    tag = player.tag,
                    role_name = role_name,
                    chat_color = player.chat_color,
                    caption = caption,
                    tooltip = tooltip,
                }
            end
        end
    end

    return row_data
end

--- Calculate the latest play time captions for each online player keyed by name
--- @return table<string, { caption: LocalisedString, tooltip: LocalisedString }>
function Elements.player_table.calculate_time_data()
    local time_data = {}
    for _, player in pairs(game.connected_players) do
        local caption, tooltip = get_time_formats(player.online_time, player.afk_time)
        time_data[player.name] = { caption = caption, tooltip = tooltip }
    end
    return time_data
end

--- Add a player row to the table and store its elements
--- @param player_table LuaGuiElement
--- @param row_data ExpGui_PlayerList.elements.player_table.row_data
function Elements.player_table.add_row(player_table, row_data)
    local rows = Elements.player_table.data[player_table].rows
    local player = row_data.player

    -- Add the button used to open the action bar
    local open_flow = player_table.add{ type = "flow" }
    local open_button = Elements.open_action_bar(open_flow, player)

    -- Add the clickable player name
    local name_label = Elements.player_name_label(player_table, {
        name = player.name,
        player = player,
        tooltip = { "exp-gui_player-list.open-map", player.name, row_data.tag, row_data.role_name },
    })
    name_label.style.font_color = row_data.chat_color

    -- Add the time played label
    local alignment = Gui.elements.aligned_flow(player_table)
    local time_label = alignment.add{
        type = "label",
        caption = row_data.caption,
        tooltip = row_data.tooltip,
    }
    time_label.style.padding = 0

    rows[player.name] = { open_button = open_button, name_label = name_label, time_label = time_label }
end

--- Rebuild all rows of a player table, used when the sort order changes
--- @param player_table LuaGuiElement
--- @param row_data ExpGui_PlayerList.elements.player_table.row_data[]
function Elements.player_table.rebuild(player_table, row_data)
    player_table.clear()
    Elements.player_table.data[player_table].rows = {}
    for _, row in ipairs(row_data) do
        Elements.player_table.add_row(player_table, row)
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

--- Refresh the time labels of a player table from precomputed time data
--- @param player_table LuaGuiElement
--- @param time_data table<string, { caption: LocalisedString, tooltip: LocalisedString }>
function Elements.player_table.refresh_times(player_table, time_data)
    for player_name, row in pairs(Elements.player_table.data[player_table].rows) do
        local data = time_data[player_name]
        if data then
            row.time_label.caption = data.caption
            row.time_label.tooltip = data.tooltip
        end
    end
end

--- Refresh the action bar, reason bar and row highlights for a player to match their selection
--- @param player LuaPlayer
function Elements.player_table.refresh_player(player)
    local selected_player = Elements.container.get_selected_player(player)
    local selected_action = Elements.container.get_selected_action(player)

    for _, player_table in Elements.player_table:online_elements(player) do
        local element_data = Elements.player_table.data[player_table]
        Elements.action_bar.refresh(element_data.action_bar, player, selected_player)
        Elements.reason_bar.refresh(element_data.reason_bar, selected_player, selected_action)

        -- Highlight the open button of the selected player
        for player_name, row in pairs(element_data.rows) do
            Elements.open_action_bar.set_highlight(row.open_button, selected_player ~= nil and player_name == selected_player.name)
        end
    end
end

--- Action bar footer holding the close button and the per action button flows
--- @class ExpGui_PlayerList.elements.action_bar: ExpElement
--- @overload fun(parent: LuaGuiElement): LuaGuiElement
Elements.action_bar = Gui.define("player_list/action_bar")
    :draw(function(_, parent)
        local action_bar = Gui.elements.subframe_base(parent, "subfooter_frame", "action_bar")
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
    end)
    :style{
        height = 35,
        padding = { 1, 3 },
    } --[[ @as any ]]

--- Update the action bar buttons to match the selection for a player, hidden when nothing is selected
--- @param action_bar LuaGuiElement
--- @param player LuaPlayer
--- @param selected_player LuaPlayer?
function Elements.action_bar.refresh(action_bar, player, selected_player)
    if not selected_player then
        action_bar.visible = false
        return
    end

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

--- Reason bar footer holding the reason entry and confirm button
--- @class ExpGui_PlayerList.elements.reason_bar: ExpElement
--- @overload fun(parent: LuaGuiElement): LuaGuiElement
Elements.reason_bar = Gui.define("player_list/reason_bar")
    :draw(function(_, parent)
        local reason_bar = Gui.elements.subframe_base(parent, "subfooter_frame", "reason_bar")
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
        entry_style.minimal_width = 158

        Elements.reason_confirm(reason_bar)
        return reason_bar
    end)
    :style{
        height = 35,
        padding = { -1, 3 },
    } --[[ @as any ]]

--- Update the reason bar visibility to match the selection, shown only while an action awaits a reason
--- @param reason_bar LuaGuiElement
--- @param selected_player LuaPlayer?
--- @param selected_action string?
function Elements.reason_bar.refresh(reason_bar, selected_player, selected_action)
    reason_bar.visible = selected_player ~= nil and selected_action ~= nil
end

--- @class ExpGui_PlayerList.elements.container.selection
--- @field selected_player LuaPlayer?
--- @field selected_action string?

--- Container added to the left gui flow
--- @class ExpGui_PlayerList.elements.container: ExpElement
--- @field data table<LuaPlayer, ExpGui_PlayerList.elements.container.selection>
Elements.container = Gui.define("player_list/container")
    :draw(function(_, parent)
        local container = Gui.elements.container(parent)

        local player_table = Elements.player_table(container)
        local action_bar = Elements.action_bar(container)
        local reason_bar = Elements.reason_bar(container)
        Elements.player_table.set_bars(player_table, action_bar, reason_bar)

        local row_data = Elements.player_table.calculate_row_data()
        Elements.player_table.rebuild(player_table, row_data)

        return Gui.elements.container.get_root_element(container)
    end) --[[ @as any ]]

--- Get or create the selection state for a player
--- @param player LuaPlayer
--- @return ExpGui_PlayerList.elements.container.selection
function Elements.container._get_selection(player)
    local selection = Elements.container.data[player]
    if not selection then
        selection = {}
        Elements.container.data[player] = selection
    end
    return selection
end

--- Get the player that actions will be performed on
--- @param player LuaPlayer
--- @return LuaPlayer?
function Elements.container.get_selected_player(player)
    return Elements.container._get_selection(player).selected_player
end

--- Get the action awaiting a reason
--- @param player LuaPlayer
--- @return string?
function Elements.container.get_selected_action(player)
    return Elements.container._get_selection(player).selected_action
end

--- Set the player that actions will be performed on, nil to clear the selection
--- @param player LuaPlayer
--- @param selected_player LuaPlayer?
function Elements.container.set_selected_player(player, selected_player)
    local selection = Elements.container._get_selection(player)
    selection.selected_player = selected_player
    if not selected_player then
        selection.selected_action = nil
    end
end

--- Toggle the player that actions will be performed on
--- @param player LuaPlayer
--- @param selected_player LuaPlayer
function Elements.container.toggle_selected_player(player, selected_player)
    if Elements.container.get_selected_player(player) == selected_player then
        Elements.container.set_selected_player(player, nil)
    else
        Elements.container.set_selected_player(player, selected_player)
    end
end

--- Set the action awaiting a reason, nil to clear it
--- @param player LuaPlayer
--- @param selected_action string?
function Elements.container.set_selected_action(player, selected_action)
    Elements.container._get_selection(player).selected_action = selected_action
end

-- Inject the accessors the actions config needs; setting an action also refreshes the gui to show the reason bar
local function select_action(player, selected_action)
    Elements.container.set_selected_action(player, selected_action)
    Elements.player_table.refresh_player(player)
end
config.set_accessors(Elements.container.get_selected_player, select_action)

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

--- Rebuild the player list for all online players, used when the sort order changes
local function redraw_player_list()
    local row_data = Elements.player_table.calculate_row_data()
    for _, player_table in Elements.player_table:online_elements() do
        Elements.player_table.rebuild(player_table, row_data)
        Elements.player_table.refresh_player(Gui.get_player(player_table))
    end
end

--- Refresh the play times for all online players
local function refresh_player_times()
    local time_data = Elements.player_table.calculate_time_data()
    for _, player_table in Elements.player_table:online_elements() do
        Elements.player_table.refresh_times(player_table, time_data)
    end
end

--- Remove a player from the list when they leave and clear any selection pointing at them
--- @param event EventData.on_player_left_game
local function on_player_left_game(event)
    local left_player = game.players[event.player_index]
    for _, player_table in Elements.player_table:online_elements() do
        Elements.player_table.remove_row(player_table, left_player.name)
        local viewing_player = Gui.get_player(player_table)
        if Elements.container.get_selected_player(viewing_player) == left_player then
            Elements.container.set_selected_player(viewing_player, nil)
            Elements.player_table.refresh_player(viewing_player)
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
        [1800] = refresh_player_times,
    }
}
