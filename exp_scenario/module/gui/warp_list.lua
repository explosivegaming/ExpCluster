--[[-- Gui - Warp List
Adds a list of warp points which players can travel between, add, and edit
]]

local Gui = require("modules/exp_gui")
local Roles = require("modules/exp_roles")
local Colors = require("modules/exp_util/include/color")
local config = require("modules.exp_legacy.config.gui.warps")

local ExpUtil = require("modules/exp_util")
local format_time = ExpUtil.format_time_factory_locale{ format = "short", hours = true, minutes = true }

local floor = math.floor
local ceil = math.ceil

--- @class ExpGui_WarpList.elements
local Elements = {}

local Styles = {
    sprite22 = { height = 22, width = 22, padding = -2 },
    sprite32 = { height = 32, width = 32, left_margin = 1 },
}

--- Rich text icons shown next to a warp name to describe why it can or can not be used
local status_icons = {
    cooldown = "[img=utility/multiplayer_waiting_icon]",
    not_available = "[img=utility/set_bar_slot]",
    bypass = "[img=utility/side_menu_bonus_icon]",
    current = "[img=utility/side_menu_map_icon]",
    connected = "[img=utility/logistic_network_panel_white]",
    different = "[img=utility/warning_white]",
}

local update_interval = floor(60 / config.update_smoothing)
local cooldown_ticks = config.cooldown_duration * 60
local proximity_radius_sq = config.standard_proximity_radius ^ 2
local spawn_radius_sq = config.spawn_proximity_radius ^ 2
local minimum_distance_sq = config.minimum_distance ^ 2

--- Names of the entities which make up a warp area, used to find them when the area is removed
local area_entity_names = {} --- @type string[]
for _, entity in ipairs(config.entities) do
    area_entity_names[#area_entity_names + 1] = entity[1]
end

--- @class ExpGui_WarpList.Warp
--- @field id number
--- @field force LuaForce
--- @field name string
--- @field icon SignalID
--- @field surface LuaSurface
--- @field position MapPosition.struct The tile the warp is centred on
--- @field last_user LuaPlayer? Nil for warps made by the scenario
--- @field last_edit_tick number
--- @field editing table<number, string> Names of the players editing the warp keyed by their index
--- @field tag LuaCustomChartTag?
--- @field electric_pole LuaEntity? Pole within the warp area, warps on the same network can be travelled between
--- @field old_tile string? The tile the warp area replaced, nil when no area was made
--- @field new boolean? True until the first edit is confirmed, discarding that edit removes the warp

--- @class ExpGui_WarpList.PlayerStatus
--- @field in_range ExpGui_WarpList.Warp? The warp the player is standing on
--- @field on_cooldown boolean
--- @field bypass_proximity boolean

--- Check a permission from the config, which says who an action applies to
--- @param player LuaPlayer
--- @param action "bypass_warp_cooldown" | "bypass_warp_proximity" | "allow_add_warp" | "allow_edit_warp"
--- @return boolean
local function has_config_permission(player, action)
    local setting = config[action]
    if setting == "all" then
        return true
    elseif setting == "admin" then
        return player.admin
    elseif setting == "exp_roles" then
        return Roles.player_has_permission(player, config["exp_roles_" .. action])
    end

    return false
end

--- Check if a player can edit a warp, the spawn warp can never be edited
--- @param player LuaPlayer
--- @param warp ExpGui_WarpList.Warp
--- @return boolean
local function has_permission_edit_warp(player, warp)
    if Elements.container.get_spawn_warp(warp.force) == warp then
        return false
    end

    if config.user_can_edit_own_warps and warp.last_user == player then
        return true
    end

    return has_config_permission(player, "allow_edit_warp")
end

--- The sprite path for a warp icon, signal ids and sprite paths name virtual signals differently
--- @param icon SignalID
--- @return SpritePath
local function icon_sprite(icon)
    if icon.type == "virtual" then
        return "virtual-signal/" .. icon.name
    end
    return (icon.type or "item") .. "/" .. icon.name
end

--- Draw a cross over something that stops a warp being added
--- @param surface LuaSurface
--- @param player LuaPlayer
--- @param target LuaEntity | MapPosition
local function draw_blocker(surface, player, target)
    rendering.draw_sprite{
        sprite = "utility/rail_path_not_possible",
        x_scale = 0.5,
        y_scale = 0.5,
        target = target,
        surface = surface,
        players = { player },
        time_to_live = 60,
    }
end

--- Button in the header which adds a warp at the player
--- @class ExpGui_WarpList.elements.add_warp_button: ExpElement
--- @overload fun(parent: LuaGuiElement): LuaGuiElement
Elements.add_warp_button = Gui.define("warp_list/add_warp_button")
    :track_all_elements()
    :draw{
        type = "sprite-button",
        sprite = "utility/add",
        tooltip = { "exp-gui_warp-list.tooltip-add" },
        style = "shortcut_bar_button",
    }
    :style(Styles.sprite22)
    :on_click(function(_, player)
        if player.controller_type ~= defines.controllers.character then return end
        local surface = player.physical_surface
        local position = player.physical_position

        local water_tiles = surface.find_tiles_filtered{
            collision_mask = "water_tile",
            radius = config.standard_proximity_radius + 1,
            position = position,
        }
        if #water_tiles > 0 then
            player.print({ "exp-gui_warp-list.add-warning-water", config.standard_proximity_radius + 1 }, Colors.orange_red)
            player.play_sound{ path = "utility/wire_pickup" }
            for _, tile in pairs(water_tiles) do
                draw_blocker(surface, player, tile.position)
            end
            return
        end

        -- A larger radius than the area because the entities a player can place are larger than tiles
        local entities = surface.find_entities_filtered{
            radius = config.standard_proximity_radius + 2.5,
            position = position,
            collision_mask = { "item", "object", "player", "water_tile" },
        }
        if #entities > 1 then -- The player's own character is always found
            player.print({ "exp-gui_warp-list.add-warning-entities", config.standard_proximity_radius + 2.5 }, Colors.orange_red)
            player.play_sound{ path = "utility/wire_pickup" }
            local character = player.character
            for _, entity in pairs(entities) do
                if entity ~= character then
                    draw_blocker(surface, player, entity)
                end
            end
            return
        end

        local force = player.force --[[@as LuaForce]]
        local warp = Elements.container.add_warp(force, surface, position, player)
        Elements.container.set_editing(warp, player, true)
    end) --[[@as any]]

--- Refresh whether the add button is enabled based on the closest warp
--- @param player LuaPlayer
--- @param blocking ExpGui_WarpList.Warp? The warp too close to add another, nil when a warp can be added
function Elements.add_warp_button.refresh_player_blocking(player, blocking)
    local tooltip = blocking and { "exp-gui_warp-list.tooltip-add-too-close", blocking.name } or { "exp-gui_warp-list.tooltip-add" }
    for _, add_warp_button in Elements.add_warp_button:tracked_elements(player) do
        add_warp_button.enabled = blocking == nil
        add_warp_button.tooltip = tooltip
    end
end

--- @class ExpGui_WarpList.elements.warp_button.element_data
--- @field warp ExpGui_WarpList.Warp

--- Button which travels to the warp, enabled when the player is allowed to use it
--- @class ExpGui_WarpList.elements.warp_button: ExpElement
--- @field data table<LuaGuiElement, ExpGui_WarpList.elements.warp_button.element_data>
--- @overload fun(parent: LuaGuiElement, warp: ExpGui_WarpList.Warp): LuaGuiElement
Elements.warp_button = Gui.define("warp_list/warp_button")
    :draw(function(_, parent, warp)
        --- @cast warp ExpGui_WarpList.Warp
        return parent.add{
            type = "sprite-button",
            sprite = icon_sprite(warp.icon),
            style = "slot_button",
        }
    end)
    :style(Styles.sprite32)
    :element_data{
        warp = Gui.from_argument(1),
    }
    :on_click(function(def, player, warp_button)
        --- @cast def ExpGui_WarpList.elements.warp_button
        Elements.container.teleport_player(player, def.data[warp_button].warp)
    end) --[[@as any]]

--- @class ExpGui_WarpList.elements.icon_picker.element_data
--- @field warp ExpGui_WarpList.Warp

--- Signal picker shown in place of the warp button while editing
--- @class ExpGui_WarpList.elements.icon_picker: ExpElement
--- @field data table<LuaGuiElement, ExpGui_WarpList.elements.icon_picker.element_data>
--- @overload fun(parent: LuaGuiElement, warp: ExpGui_WarpList.Warp): LuaGuiElement
Elements.icon_picker = Gui.define("warp_list/icon_picker")
    :draw(function(_, parent, warp)
        --- @cast warp ExpGui_WarpList.Warp
        return parent.add{
            type = "choose-elem-button",
            elem_type = "signal",
            signal = warp.icon,
            tooltip = { "exp-gui_warp-list.tooltip-icon" },
        }
    end)
    :style(Styles.sprite32)
    :element_data{
        warp = Gui.from_argument(1),
    } --[[@as any]]

--- Get the icon chosen in a picker, the game omits the type for items
--- @param icon_picker LuaGuiElement
--- @return SignalID
function Elements.icon_picker.get_icon(icon_picker)
    local icon = icon_picker.elem_value --[[@as SignalID?]]
    if not icon then
        return Elements.icon_picker.data[icon_picker].warp.icon
    end
    icon.type = icon.type or "item"
    return icon
end

--- Icon describing whether the warp can be used
--- @class ExpGui_WarpList.elements.status_label: ExpElement
--- @overload fun(parent: LuaGuiElement): LuaGuiElement
Elements.status_label = Gui.define("warp_list/status_label")
    :draw{
        type = "label",
        caption = status_icons.not_available,
    }
    :style{
        top_padding = 1, -- Keeps the icon in place when the taller textfield is shown
        single_line = false,
    } --[[@as any]]

--- @class ExpGui_WarpList.elements.name_label.element_data
--- @field warp ExpGui_WarpList.Warp

--- Warp name, clicking it opens the map at the warp
--- @class ExpGui_WarpList.elements.name_label: ExpElement
--- @field data table<LuaGuiElement, ExpGui_WarpList.elements.name_label.element_data>
--- @overload fun(parent: LuaGuiElement, warp: ExpGui_WarpList.Warp): LuaGuiElement
Elements.name_label = Gui.define("warp_list/name_label")
    :draw(function(_, parent, warp)
        --- @cast warp ExpGui_WarpList.Warp
        return parent.add{
            type = "label",
            caption = warp.name,
        }
    end)
    :style{
        single_line = true,
        left_padding = 2,
        right_padding = 2,
        horizontally_stretchable = true,
    }
    :element_data{
        warp = Gui.from_argument(1),
    }
    :on_click(function(def, player, name_label)
        --- @cast def ExpGui_WarpList.elements.name_label
        local warp = def.data[name_label].warp
        player.set_controller{ type = defines.controllers.remote, position = warp.position, surface = warp.surface }
    end) --[[@as any]]

--- Refresh the name and last edit of the label
--- @param name_label LuaGuiElement
--- @param warp ExpGui_WarpList.Warp
function Elements.name_label.refresh(name_label, warp)
    local last_user = warp.last_user and warp.last_user.name or "<server>"
    name_label.caption = warp.name
    name_label.tooltip = { "exp-gui_warp-list.tooltip-last-edit", last_user, format_time(warp.last_edit_tick) }
end

--- @class ExpGui_WarpList.elements.name_field.element_data
--- @field warp ExpGui_WarpList.Warp
--- @field icon_picker LuaGuiElement

--- Textfield shown in place of the name label while editing, confirming it saves the edit
--- @class ExpGui_WarpList.elements.name_field: ExpElement
--- @field data table<LuaGuiElement, ExpGui_WarpList.elements.name_field.element_data>
--- @overload fun(parent: LuaGuiElement, warp: ExpGui_WarpList.Warp, icon_picker: LuaGuiElement): LuaGuiElement
Elements.name_field = Gui.define("warp_list/name_field")
    :draw(function(_, parent, warp)
        --- @cast warp ExpGui_WarpList.Warp
        return parent.add{
            type = "textfield",
            text = warp.name,
            clear_and_focus_on_right_click = true,
        }
    end)
    :style{
        minimal_width = 10,
        maximal_width = 300,
        horizontally_squashable = true,
        horizontally_stretchable = true,
        height = 22,
        padding = -2,
        left_margin = 2,
        right_margin = 2,
    }
    :element_data{
        warp = Gui.from_argument(1),
        icon_picker = Gui.from_argument(2),
    }
    :on_confirmed(function(def, player, name_field)
        --- @cast def ExpGui_WarpList.elements.name_field
        local elements = def.data[name_field]
        local icon = Elements.icon_picker.get_icon(elements.icon_picker)
        Elements.container.update_warp(elements.warp, name_field.text, icon, player)
    end) --[[@as any]]

--- @class ExpGui_WarpList.elements.confirm_edit_button.element_data
--- @field warp ExpGui_WarpList.Warp
--- @field name_field LuaGuiElement
--- @field icon_picker LuaGuiElement

--- Button which saves the name and icon being edited
--- @class ExpGui_WarpList.elements.confirm_edit_button: ExpElement
--- @field data table<LuaGuiElement, ExpGui_WarpList.elements.confirm_edit_button.element_data>
--- @overload fun(parent: LuaGuiElement, warp: ExpGui_WarpList.Warp, name_field: LuaGuiElement, icon_picker: LuaGuiElement): LuaGuiElement
Elements.confirm_edit_button = Gui.define("warp_list/confirm_edit_button")
    :draw{
        type = "sprite-button",
        sprite = "utility/confirm_slot",
        tooltip = { "exp-gui_warp-list.tooltip-confirm" },
        style = "shortcut_bar_button_green",
    }
    :style(Styles.sprite22)
    :element_data{
        warp = Gui.from_argument(1),
        name_field = Gui.from_argument(2),
        icon_picker = Gui.from_argument(3),
    }
    :on_click(function(def, player, confirm_edit_button)
        --- @cast def ExpGui_WarpList.elements.confirm_edit_button
        local elements = def.data[confirm_edit_button]
        local icon = Elements.icon_picker.get_icon(elements.icon_picker)
        Elements.container.update_warp(elements.warp, elements.name_field.text, icon, player)
    end) --[[@as any]]

--- @class ExpGui_WarpList.elements.discard_edit_button.element_data
--- @field warp ExpGui_WarpList.Warp

--- Button which discards an edit, a warp which was never confirmed is removed
--- @class ExpGui_WarpList.elements.discard_edit_button: ExpElement
--- @field data table<LuaGuiElement, ExpGui_WarpList.elements.discard_edit_button.element_data>
--- @overload fun(parent: LuaGuiElement, warp: ExpGui_WarpList.Warp): LuaGuiElement
Elements.discard_edit_button = Gui.define("warp_list/discard_edit_button")
    :draw{
        type = "sprite-button",
        sprite = "utility/close_black",
        tooltip = { "exp-gui_warp-list.tooltip-discard" },
        style = "shortcut_bar_button_red",
    }
    :style(Styles.sprite22)
    :element_data{
        warp = Gui.from_argument(1),
    }
    :on_click(function(def, player, discard_edit_button)
        --- @cast def ExpGui_WarpList.elements.discard_edit_button
        local warp = def.data[discard_edit_button].warp
        if warp.new then
            Elements.container.remove_warp(warp)
        else
            Elements.container.set_editing(warp, player, false)
        end
    end) --[[@as any]]

--- @class ExpGui_WarpList.elements.edit_warp_button.element_data
--- @field warp ExpGui_WarpList.Warp

--- Button which starts editing a warp
--- @class ExpGui_WarpList.elements.edit_warp_button: ExpElement
--- @field data table<LuaGuiElement, ExpGui_WarpList.elements.edit_warp_button.element_data>
--- @overload fun(parent: LuaGuiElement, warp: ExpGui_WarpList.Warp): LuaGuiElement
Elements.edit_warp_button = Gui.define("warp_list/edit_warp_button")
    :draw{
        type = "sprite-button",
        sprite = "utility/rename_icon",
        tooltip = { "exp-gui_warp-list.tooltip-edit-none" },
        style = "shortcut_bar_button",
    }
    :style(Styles.sprite22)
    :element_data{
        warp = Gui.from_argument(1),
    }
    :on_click(function(def, player, edit_warp_button)
        --- @cast def ExpGui_WarpList.elements.edit_warp_button
        Elements.container.set_editing(def.data[edit_warp_button].warp, player, true)
    end) --[[@as any]]

--- Refresh the tooltip which lists who is editing the warp
--- @param edit_warp_button LuaGuiElement
--- @param warp ExpGui_WarpList.Warp
function Elements.edit_warp_button.refresh(edit_warp_button, warp)
    if next(warp.editing) then
        local player_names = table.get_values(warp.editing)
        edit_warp_button.hovered_sprite = "utility/warning_icon"
        edit_warp_button.tooltip = { "exp-gui_warp-list.tooltip-edit", table.concat(player_names, ", ") }
    else
        edit_warp_button.hovered_sprite = "utility/rename_icon"
        edit_warp_button.tooltip = { "exp-gui_warp-list.tooltip-edit-none" }
    end
end

--- @class ExpGui_WarpList.elements.remove_warp_button.element_data
--- @field warp ExpGui_WarpList.Warp

--- Button which removes a warp along with its area and map tag
--- @class ExpGui_WarpList.elements.remove_warp_button: ExpElement
--- @field data table<LuaGuiElement, ExpGui_WarpList.elements.remove_warp_button.element_data>
--- @overload fun(parent: LuaGuiElement, warp: ExpGui_WarpList.Warp): LuaGuiElement
Elements.remove_warp_button = Gui.define("warp_list/remove_warp_button")
    :draw{
        type = "sprite-button",
        sprite = "utility/trash",
        tooltip = { "exp-gui_warp-list.tooltip-remove" },
        style = "shortcut_bar_button_red",
    }
    :style(Styles.sprite22)
    :element_data{
        warp = Gui.from_argument(1),
    }
    :on_click(function(def, _, remove_warp_button)
        --- @cast def ExpGui_WarpList.elements.remove_warp_button
        Elements.container.remove_warp(def.data[remove_warp_button].warp)
    end) --[[@as any]]

--- @class ExpGui_WarpList.elements.warp_table.row
--- @field warp ExpGui_WarpList.Warp
--- @field icon_flow LuaGuiElement
--- @field name_flow LuaGuiElement
--- @field action_flow LuaGuiElement
--- @field warp_button LuaGuiElement
--- @field icon_picker LuaGuiElement
--- @field status_label LuaGuiElement
--- @field name_label LuaGuiElement
--- @field name_field LuaGuiElement
--- @field confirm_edit_button LuaGuiElement
--- @field discard_edit_button LuaGuiElement
--- @field edit_warp_button LuaGuiElement
--- @field remove_warp_button LuaGuiElement

--- @class ExpGui_WarpList.elements.warp_table.element_data
--- @field rows table<number, ExpGui_WarpList.elements.warp_table.row> Keyed by warp id

--- Table with a row of icon, name, and actions for each warp of the player's force
--- @class ExpGui_WarpList.elements.warp_table: ExpElement
--- @field data table<LuaGuiElement, ExpGui_WarpList.elements.warp_table.element_data>
--- @overload fun(parent: LuaGuiElement): LuaGuiElement
Elements.warp_table = Gui.define("warp_list/warp_table")
    :track_all_elements()
    :element_data{ rows = {} }
    :draw(function(_, parent)
        local warp_table = Gui.elements.scroll_table(parent, 250, 3, "scroll")
        -- Always showing the scrollbar stops the gui changing width as warps are added
        assert(warp_table.parent).vertical_scroll_policy = "always"
        return warp_table
    end)
    :style{
        top_cell_padding = 3,
        bottom_cell_padding = 3,
    } --[[@as any]]

--- Add a row for a warp
--- @param warp_table LuaGuiElement
--- @param warp ExpGui_WarpList.Warp
--- @return ExpGui_WarpList.elements.warp_table.row
function Elements.warp_table.add_row(warp_table, warp)
    local icon_flow = warp_table.add{ type = "flow" }
    icon_flow.style.padding = 0
    local warp_button = Elements.warp_button(icon_flow, warp)
    local icon_picker = Elements.icon_picker(icon_flow, warp)

    local name_flow = warp_table.add{ type = "flow" }
    name_flow.style.padding = 0
    local status_label = Elements.status_label(name_flow)
    local name_label = Elements.name_label(name_flow, warp)
    local name_field = Elements.name_field(name_flow, warp, icon_picker)

    local action_flow = warp_table.add{ type = "flow" }
    action_flow.style.padding = 0
    local confirm_edit_button = Elements.confirm_edit_button(action_flow, warp, name_field, icon_picker)
    local discard_edit_button = Elements.discard_edit_button(action_flow, warp)
    local edit_warp_button = Elements.edit_warp_button(action_flow, warp)
    local remove_warp_button = Elements.remove_warp_button(action_flow, warp)

    local row = {
        warp = warp,
        icon_flow = icon_flow,
        name_flow = name_flow,
        action_flow = action_flow,
        warp_button = warp_button,
        icon_picker = icon_picker,
        status_label = status_label,
        name_label = name_label,
        name_field = name_field,
        confirm_edit_button = confirm_edit_button,
        discard_edit_button = discard_edit_button,
        edit_warp_button = edit_warp_button,
        remove_warp_button = remove_warp_button,
    }

    Elements.warp_table.data[warp_table].rows[warp.id] = row
    return row
end

--- Remove the row for a warp
--- @param warp_table LuaGuiElement
--- @param warp ExpGui_WarpList.Warp
function Elements.warp_table.remove_row(warp_table, warp)
    local rows = Elements.warp_table.data[warp_table].rows
    local row = rows[warp.id]
    if not row then return end
    rows[warp.id] = nil
    row.icon_flow.destroy()
    row.name_flow.destroy()
    row.action_flow.destroy()
end

--- Refresh whether a warp can be used from where the player is
--- @param row ExpGui_WarpList.elements.warp_table.row
--- @param status ExpGui_WarpList.PlayerStatus
function Elements.warp_table._refresh_row_status(row, status)
    local warp = row.warp
    local in_range = status.in_range
    local position = warp.position
    local tooltip, icon, enabled

    if not in_range then
        if status.bypass_proximity then
            tooltip, icon, enabled = { "exp-gui_warp-list.tooltip-goto-bypass", position.x, position.y }, status_icons.bypass, true
        else
            tooltip, icon, enabled = { "exp-gui_warp-list.tooltip-goto-disabled" }, status_icons.not_available, false
        end
    elseif in_range == warp then
        tooltip, icon, enabled = { "exp-gui_warp-list.tooltip-goto-same-warp" }, status_icons.current, false
    elseif status.on_cooldown then
        tooltip, icon, enabled = { "exp-gui_warp-list.tooltip-goto-cooldown" }, status_icons.cooldown, false
    else
        -- Warps are connected when their poles share an electric network, missing poles never match
        local network_id = warp.electric_pole and warp.electric_pole.valid and warp.electric_pole.electric_network_id or -1
        local in_range_network_id = in_range.electric_pole and in_range.electric_pole.valid and in_range.electric_pole.electric_network_id or -2
        if network_id == in_range_network_id then
            tooltip, icon, enabled = { "exp-gui_warp-list.tooltip-goto", position.x, position.y }, status_icons.connected, true
        elseif status.bypass_proximity then
            tooltip, icon, enabled = { "exp-gui_warp-list.tooltip-goto-bypass-different-network", position.x, position.y }, status_icons.bypass, true
        else
            tooltip, icon, enabled = { "exp-gui_warp-list.tooltip-goto-different-network" }, status_icons.different, false
        end
    end

    row.warp_button.tooltip = tooltip
    row.warp_button.enabled = enabled
    row.status_label.tooltip = tooltip
    row.status_label.caption = icon
    row.name_label.style.font = enabled and "default-semibold" or "default"
end

--- Refresh a row to match its warp, the player's permissions, and where the player is
--- @param warp_table LuaGuiElement
--- @param row ExpGui_WarpList.elements.warp_table.row
--- @param status ExpGui_WarpList.PlayerStatus
function Elements.warp_table.refresh_row(warp_table, row, status)
    local player = Gui.get_player(warp_table)
    local warp = row.warp
    local can_edit = has_permission_edit_warp(player, warp)
    local editing = warp.editing[player.index] ~= nil

    Elements.edit_warp_button.refresh(row.edit_warp_button, warp)
    Elements.name_label.refresh(row.name_label, warp)

    row.warp_button.visible = not editing
    row.icon_picker.visible = editing
    row.name_label.visible = not editing
    row.name_field.visible = editing
    row.confirm_edit_button.visible = editing
    row.discard_edit_button.visible = editing
    row.edit_warp_button.visible = can_edit and not editing
    row.remove_warp_button.visible = can_edit and not editing

    if editing then
        row.name_field.focus()
        assert(warp_table.parent).scroll_to_element(row.name_field, "top-third")
    else
        row.warp_button.sprite = icon_sprite(warp.icon)
        row.icon_picker.elem_value = warp.icon
        row.name_field.text = warp.name
    end

    Elements.warp_table._refresh_row_status(row, status)
end

--- Rebuild every row in the order of the warps
--- @param warp_table LuaGuiElement
--- @param warps ExpGui_WarpList.Warp[]
--- @param status ExpGui_WarpList.PlayerStatus
function Elements.warp_table.rebuild(warp_table, warps, status)
    warp_table.clear()
    Elements.warp_table.data[warp_table].rows = {}
    for _, warp in ipairs(warps) do
        local row = Elements.warp_table.add_row(warp_table, warp)
        Elements.warp_table.refresh_row(warp_table, row, status)
    end
end

--- Refresh the row of one warp for the online players of its force
--- @param warp ExpGui_WarpList.Warp
function Elements.warp_table.refresh_row_force(warp)
    for player, warp_table in Elements.warp_table:online_elements(warp.force) do
        --- @cast player -nil
        local row = Elements.warp_table.data[warp_table].rows[warp.id]
        if row then
            Elements.warp_table.refresh_row(warp_table, row, Elements.container.get_status(player))
        end
    end
end

--- Refresh whether each warp can be used from where the player is
--- @param player LuaPlayer
function Elements.warp_table.refresh_status_player(player)
    local status = Elements.container.get_status(player)
    for _, warp_table in Elements.warp_table:tracked_elements(player) do
        for _, row in pairs(Elements.warp_table.data[warp_table].rows) do
            Elements.warp_table._refresh_row_status(row, status)
        end
    end
end

--- Rebuild the rows for a player, used when their force or permissions change
--- @param player LuaPlayer
function Elements.warp_table.rebuild_player(player)
    local warps = Elements.container.get_warps(player.force --[[@as LuaForce]])
    local status = Elements.container.get_status(player)
    for _, warp_table in Elements.warp_table:tracked_elements(player) do
        Elements.warp_table.rebuild(warp_table, warps, status)
    end
end

--- Rebuild the rows for the online players of a force, used when the warps change
--- @param force LuaForce
function Elements.warp_table.rebuild_force(force)
    local warps = Elements.container.get_warps(force)
    for player, warp_table in Elements.warp_table:online_elements(force) do
        --- @cast player -nil
        Elements.warp_table.rebuild(warp_table, warps, Elements.container.get_status(player))
    end
end

--- Progress bar which fills as the warp cooldown runs out
--- @class ExpGui_WarpList.elements.cooldown_bar: ExpElement
--- @overload fun(parent: LuaGuiElement): LuaGuiElement
Elements.cooldown_bar = Gui.define("warp_list/cooldown_bar")
    :track_all_elements()
    :draw{
        type = "progressbar",
        value = 1,
        tooltip = { "exp-gui_warp-list.tooltip-cooldown-none", config.cooldown_duration },
    }
    :style{
        horizontally_stretchable = true,
        color = Colors.light_blue,
    } --[[@as any]]

--- Refresh the bar to show the ticks left on the cooldown
--- @param cooldown_bar LuaGuiElement
--- @param cooldown number
function Elements.cooldown_bar.refresh(cooldown_bar, cooldown)
    if cooldown > 0 then
        cooldown_bar.value = 1 - cooldown / cooldown_ticks
        cooldown_bar.tooltip = { "exp-gui_warp-list.tooltip-cooldown", ceil(cooldown / 60) }
    else
        cooldown_bar.value = 1
        cooldown_bar.tooltip = { "exp-gui_warp-list.tooltip-cooldown-none", config.cooldown_duration }
    end
end

--- Refresh the bars of a player
--- @param player LuaPlayer
--- @param cooldown number
function Elements.cooldown_bar.refresh_player(player, cooldown)
    for _, cooldown_bar in Elements.cooldown_bar:tracked_elements(player) do
        Elements.cooldown_bar.refresh(cooldown_bar, cooldown)
    end
end

--- @class ExpGui_WarpList.elements.container.elements
--- @field frame LuaGuiElement
--- @field add_warp_button LuaGuiElement
--- @field warp_table LuaGuiElement
--- @field cooldown_bar LuaGuiElement

--- @class ExpGui_WarpList.elements.container.force_data
--- @field warps ExpGui_WarpList.Warp[] The spawn warp first, then by name
--- @field spawn ExpGui_WarpList.Warp?
--- @field next_warp_id number

--- @class ExpGui_WarpList.elements.container.player_data
--- @field cooldown number Ticks until the player can warp again
--- @field in_range ExpGui_WarpList.Warp? The warp the player is standing on
--- @field blocking ExpGui_WarpList.Warp? The warp too close for another to be added
--- @field keep_open boolean True once the player toggles the list themselves, which stops it hiding when they leave a warp

--- @class ExpGui_WarpList.elements.container.data
--- @field [LuaGuiElement] ExpGui_WarpList.elements.container.elements
--- @field [LuaForce] ExpGui_WarpList.elements.container.force_data
--- @field [LuaPlayer] ExpGui_WarpList.elements.container.player_data

--- Container added to the left gui flow
--- @class ExpGui_WarpList.elements.container: ExpElement
--- @field data ExpGui_WarpList.elements.container.data
Elements.container = Gui.define("warp_list/container")
    :draw(function(def, parent)
        --- @cast def ExpGui_WarpList.elements.container
        local player = Gui.get_player(parent)
        local allow_add_warp = has_config_permission(player, "allow_add_warp")
        local container = Gui.elements.container(parent, allow_add_warp and 268 or 220)

        local header = Gui.elements.header(container, {
            caption = { "exp-gui_warp-list.caption-main" },
            tooltip = {
                "exp-gui_warp-list.tooltip-sub",
                config.cooldown_duration,
                config.standard_proximity_radius,
                { "exp-gui_warp-list.tooltip-sub-current", status_icons.current },
                { "exp-gui_warp-list.tooltip-sub-connected", status_icons.connected },
                { "exp-gui_warp-list.tooltip-sub-different", status_icons.different },
                { "exp-gui_warp-list.tooltip-sub-cooldown", status_icons.cooldown },
                { "exp-gui_warp-list.tooltip-sub-not-available", status_icons.not_available },
                { "exp-gui_warp-list.tooltip-sub-bypass", status_icons.bypass },
            },
        })

        local add_warp_button = Elements.add_warp_button(header)
        add_warp_button.visible = allow_add_warp

        local warp_table = Elements.warp_table(container)
        local force = player.force --[[@as LuaForce]]
        Elements.warp_table.rebuild(warp_table, def.get_warps(force), def.get_status(player))

        local cooldown_bar = Elements.cooldown_bar(container)
        Elements.cooldown_bar.refresh(cooldown_bar, def._get_player_data(player).cooldown)

        local root = Gui.elements.container.get_root_element(container)
        def.data[root] = {
            frame = container,
            add_warp_button = add_warp_button,
            warp_table = warp_table,
            cooldown_bar = cooldown_bar,
        }

        return root
    end) --[[@as any]]

--- Get or create the data for a force
--- @param force LuaForce
--- @return ExpGui_WarpList.elements.container.force_data
function Elements.container._get_force_data(force)
    local force_data = Elements.container.data[force]
    if not force_data then
        force_data = { warps = {}, next_warp_id = 1 }
        Elements.container.data[force] = force_data
    end
    return force_data
end

--- Get or create the data for a player
--- @param player LuaPlayer
--- @return ExpGui_WarpList.elements.container.player_data
function Elements.container._get_player_data(player)
    local player_data = Elements.container.data[player]
    if not player_data then
        player_data = { cooldown = 0, keep_open = false }
        Elements.container.data[player] = player_data
    end
    return player_data
end

--- Get the warps of a force, the spawn warp first and then by name
--- @param force LuaForce
--- @return ExpGui_WarpList.Warp[]
function Elements.container.get_warps(force)
    return Elements.container._get_force_data(force).warps
end

--- Get the spawn warp of a force
--- @param force LuaForce
--- @return ExpGui_WarpList.Warp?
function Elements.container.get_spawn_warp(force)
    return Elements.container._get_force_data(force).spawn
end

--- Get what decides which warps a player can use
--- @param player LuaPlayer
--- @return ExpGui_WarpList.PlayerStatus
function Elements.container.get_status(player)
    local player_data = Elements.container._get_player_data(player)
    return {
        in_range = player_data.in_range,
        on_cooldown = player_data.cooldown > 0,
        bypass_proximity = has_config_permission(player, "bypass_warp_proximity"),
    }
end

--- Keep the warps of a force in display order
--- @param force_data ExpGui_WarpList.elements.container.force_data
function Elements.container._sort_warps(force_data)
    local spawn = force_data.spawn
    table.sort(force_data.warps, function(a, b)
        if a == spawn then return true end
        if b == spawn then return false end
        if a.name == b.name then return a.id < b.id end
        return a.name < b.name
    end)
end

--- Add or update the map tag of a warp
--- @param warp ExpGui_WarpList.Warp
function Elements.container._make_tag(warp)
    local tag = warp.tag
    if tag and tag.valid then
        tag.text = "Warp: " .. warp.name
        tag.icon = warp.icon
        return
    end

    local position = warp.position
    warp.tag = warp.force.add_chart_tag(warp.surface, {
        position = { x = position.x + 0.5, y = position.y + 0.5 },
        text = "Warp: " .. warp.name,
        icon = warp.icon,
    })
end

--- Remove the map tag of a warp
--- @param warp ExpGui_WarpList.Warp
function Elements.container._remove_tag(warp)
    local tag = warp.tag
    if tag and tag.valid then
        tag.destroy()
    end
    warp.tag = nil
end

--- Place the tiles and entities which mark a warp on the ground
--- @param warp ExpGui_WarpList.Warp
function Elements.container._make_area(warp)
    local surface = warp.surface
    local position = warp.position
    warp.old_tile = surface.get_tile(position.x, position.y).name

    local tiles = {}
    for index, tile in ipairs(config.tiles) do
        tiles[index] = { name = tile[1], position = { x = tile[2] + position.x, y = tile[3] + position.y } }
    end
    surface.set_tiles(tiles)

    for _, entity_config in ipairs(config.entities) do
        local entity = assert(surface.create_entity{
            name = entity_config[1],
            position = { x = entity_config[2] + position.x, y = entity_config[3] + position.y },
            force = "neutral",
        })
        entity.destructible = false
        entity.health = 0
        entity.minable_flag = false
        entity.rotatable = false

        if entity.type == "electric-pole" then
            warp.electric_pole = entity
        end
    end
end

--- Restore the ground under a warp and remove its entities
--- @param warp ExpGui_WarpList.Warp
function Elements.container._remove_area(warp)
    local old_tile = warp.old_tile
    if not old_tile then return end

    local surface = warp.surface
    local position = warp.position
    local tiles = {}
    for index, tile in ipairs(config.tiles) do
        tiles[index] = { name = old_tile, position = { x = tile[2] + position.x, y = tile[3] + position.y } }
    end
    surface.set_tiles(tiles)

    local radius = config.standard_proximity_radius
    local area = {
        left_top = { x = position.x - radius, y = position.y - radius },
        right_bottom = { x = position.x + radius, y = position.y + radius },
    }
    local entities = surface.find_entities_filtered{ force = "neutral", area = area, name = area_entity_names }
    for _, entity in pairs(entities) do
        if entity.destructible == false then
            entity.destructible = true
            entity.die(entity.force)
        end
    end

    -- The area may not be covered by a radar
    warp.force.chart(surface, area)
end

--- Add a warp for a force, when added by a player it is new until they confirm their first edit
--- @param force LuaForce
--- @param surface LuaSurface
--- @param position MapPosition.struct
--- @param player LuaPlayer?
--- @param name string?
--- @return ExpGui_WarpList.Warp
function Elements.container.add_warp(force, surface, position, player, name)
    local force_data = Elements.container._get_force_data(force)
    local id = force_data.next_warp_id
    force_data.next_warp_id = id + 1

    --- @type ExpGui_WarpList.Warp
    local warp = {
        id = id,
        force = force,
        name = name or "New warp",
        icon = { type = config.default_icon.type, name = config.default_icon.name },
        surface = surface,
        position = { x = floor(position.x), y = floor(position.y) },
        last_user = player,
        last_edit_tick = game.tick,
        editing = {},
    }

    -- Warps added by a player start in edit mode, discarding that edit removes them again
    if player then
        warp.new = true
        Elements.container._make_area(warp)
    end

    force_data.warps[#force_data.warps + 1] = warp
    Elements.container._sort_warps(force_data)
    Elements.container._make_tag(warp)

    Elements.warp_table.rebuild_force(force)
    return warp
end

--- Remove a warp along with its area and map tag
--- @param warp ExpGui_WarpList.Warp
function Elements.container.remove_warp(warp)
    local force_data = Elements.container._get_force_data(warp.force)
    table.remove_element(force_data.warps, warp)
    if force_data.spawn == warp then
        force_data.spawn = nil
    end

    Elements.container._remove_tag(warp)
    Elements.container._remove_area(warp)

    -- Offline players are corrected by their next proximity update
    for _, player in pairs(warp.force.connected_players) do
        local player_data = Elements.container._get_player_data(player)
        if player_data.in_range == warp then player_data.in_range = nil end
        if player_data.blocking == warp then player_data.blocking = nil end
    end

    for _, warp_table in Elements.warp_table:online_elements(warp.force) do
        Elements.warp_table.remove_row(warp_table, warp)
    end
end

--- Save a new name and icon for a warp, which also ends the player's edit
--- @param warp ExpGui_WarpList.Warp
--- @param name string
--- @param icon SignalID
--- @param player LuaPlayer
function Elements.container.update_warp(warp, name, icon, player)
    warp.name = name
    warp.icon = icon
    warp.last_user = player
    warp.last_edit_tick = game.tick
    warp.editing[player.index] = nil
    warp.new = nil

    Elements.container._sort_warps(Elements.container._get_force_data(warp.force))
    Elements.container._make_tag(warp)
    Elements.warp_table.rebuild_force(warp.force)
end

--- Start or stop a player editing a warp
--- @param warp ExpGui_WarpList.Warp
--- @param player LuaPlayer
--- @param editing boolean
function Elements.container.set_editing(warp, player, editing)
    warp.editing[player.index] = editing and player.name or nil
    Elements.warp_table.refresh_row_force(warp)
end

--- Make a warp the spawn of its force, the force respawns there
--- @param warp ExpGui_WarpList.Warp
function Elements.container.set_spawn_warp(warp)
    local force_data = Elements.container._get_force_data(warp.force)
    force_data.spawn = warp
    Elements.container._sort_warps(force_data)
    warp.force.set_spawn_position(warp.position, warp.surface)
end

--- Move a player to a warp and start their cooldown
--- @param player LuaPlayer
--- @param warp ExpGui_WarpList.Warp
function Elements.container.teleport_player(player, warp)
    local surface = warp.surface
    local position = { x = warp.position.x + 0.5, y = warp.position.y + 0.5 }

    local vehicle = player.vehicle
    if vehicle then
        local vehicle_position = surface.find_non_colliding_position(vehicle.name, position, 32, 1)
        -- Only cars can be teleported between surfaces
        if vehicle.type == "car" then
            vehicle.teleport(vehicle_position, surface)
        elseif surface == vehicle.surface then
            if not vehicle.teleport(vehicle_position) then
                player.driving = false
                player.teleport(surface.find_non_colliding_position("character", position, 32, 1), surface)
            end
        end
    else
        player.teleport(surface.find_non_colliding_position("character", position, 32, 1), surface)
    end

    local player_data = Elements.container._get_player_data(player)
    if not has_config_permission(player, "bypass_warp_cooldown") then
        player_data.cooldown = cooldown_ticks
        Elements.cooldown_bar.refresh_player(player, cooldown_ticks)
    end
    player_data.in_range = warp
    Elements.warp_table.refresh_status_player(player)
end

--- Refresh the parts of a player's gui which depend on their permissions
--- @param player LuaPlayer
function Elements.container.refresh_player(player)
    local allow_add_warp = has_config_permission(player, "allow_add_warp")
    for _, container in Elements.container:tracked_elements(player) do
        local elements = Elements.container.data[container]
        elements.frame.style.minimal_width = allow_add_warp and 268 or 220
        elements.add_warp_button.visible = allow_add_warp
    end
    Elements.warp_table.rebuild_player(player)
end

--- Count down the cooldown of a player
--- @param player LuaPlayer
--- @param player_data ExpGui_WarpList.elements.container.player_data
function Elements.container._update_cooldown(player, player_data)
    if player_data.cooldown == 0 then return end
    local cooldown = player_data.cooldown - update_interval
    if cooldown < 0 then cooldown = 0 end
    player_data.cooldown = cooldown

    Elements.cooldown_bar.refresh_player(player, cooldown)
    if cooldown == 0 then
        Elements.warp_table.refresh_status_player(player)
    end
end

--- Find which warp a player is standing on and whether one can be added where they are
--- @param player LuaPlayer
--- @param player_data ExpGui_WarpList.elements.container.player_data
function Elements.container._update_proximity(player, player_data)
    local force_data = Elements.container._get_force_data(player.force --[[@as LuaForce]])
    local surface = player.physical_surface
    local position = player.physical_position
    local px, py = position.x, position.y

    local closest, closest_distance = nil, nil --- @type ExpGui_WarpList.Warp?, number?
    for _, warp in ipairs(force_data.warps) do
        if warp.surface == surface then
            local dx, dy = px - warp.position.x, py - warp.position.y
            local distance = dx * dx + dy * dy
            if not closest_distance or distance < closest_distance then
                closest, closest_distance = warp, distance
            end
        end
    end

    local in_range = nil --- @type ExpGui_WarpList.Warp?
    if closest and closest_distance < (closest == force_data.spawn and spawn_radius_sq or proximity_radius_sq) then
        in_range = closest
    end
    if in_range ~= player_data.in_range then
        player_data.in_range = in_range
        if not player_data.keep_open then
            Gui.toolbar.set_left_element_visible_state(Elements.container, player, in_range ~= nil)
        end
        Elements.warp_table.refresh_status_player(player)
    end

    local blocking = nil --- @type ExpGui_WarpList.Warp?
    if closest and closest_distance <= minimum_distance_sq then
        blocking = closest
    end
    if blocking ~= player_data.blocking then
        player_data.blocking = blocking
        Elements.add_warp_button.refresh_player_blocking(player, blocking)
    end
end

--- Add the element to the left flow with a toolbar button
Gui.add_left_element(Elements.container, false)
Gui.toolbar.create_button{
    name = "toggle_warp_list",
    left_element = Elements.container,
    sprite = config.default_icon.type .. "/" .. config.default_icon.name,
    tooltip = { "exp-gui_warp-list.tooltip-main" },
    visible = function(player, element)
        return Roles.player_has_permission(player, "exp_scenario.gui.warp_list")
    end
}:on_click(function(def, player)
    -- A list the player opened themselves stays open when they leave a warp
    Elements.container._get_player_data(player).keep_open = Gui.toolbar.get_button_toggled_state(def, player)
end)

--- Give a force a spawn warp when its first player is created
--- @param event EventData.on_player_created
local function on_player_created(event)
    local player = Gui.get_player(event)
    local force = player.force --[[@as LuaForce]]
    if Elements.container.get_spawn_warp(force) then return end

    local surface = player.physical_surface
    local position = force.get_spawn_position(surface)
    local warp = Elements.container.add_warp(force, surface, position, nil, "Spawn")
    Elements.container.set_spawn_warp(warp)

    -- Spawn has no warp area, so any pole nearby connects it to the network
    local poles = surface.find_entities_filtered{ type = "electric-pole", position = position, radius = 20, limit = 1 }
    warp.electric_pole = poles[1]
end

--- Rebuild the gui for a player as it may be outdated
--- @param event EventData.on_player_joined_game | EventData.on_player_changed_force
local function refresh_player_warps(event)
    local player = Gui.get_player(event)
    Elements.container.refresh_player(player)
    Elements.cooldown_bar.refresh_player(player, Elements.container._get_player_data(player).cooldown)
end

--- Rebuild the gui for a player as their permissions may have changed
--- @param event EventData.ExpRoles.on_player_roles_changed
local function refresh_player_permissions(event)
    Elements.container.refresh_player(Gui.get_player(event))
end

--- Restore the map tag of a warp when a player edits or removes it
--- @param event EventData.on_chart_tag_modified | EventData.on_chart_tag_removed
local function on_chart_tag_changed(event)
    if not event.player_index then return end
    for _, warp in ipairs(Elements.container.get_warps(event.force)) do
        local tag = warp.tag
        if not tag or not tag.valid or tag == event.tag then
            if event.name == defines.events.on_chart_tag_removed then
                warp.tag = nil
            end
            Elements.container._make_tag(warp)
        end
    end
end

--- Count down cooldowns and check where each player is
local function update_players()
    for _, player in pairs(game.connected_players) do
        local player_data = Elements.container._get_player_data(player)
        Elements.container._update_cooldown(player, player_data)
        Elements.container._update_proximity(player, player_data)
    end
end

local e = defines.events

return {
    elements = Elements,
    events = {
        [e.on_player_created] = on_player_created,
        [e.on_player_joined_game] = refresh_player_warps,
        [e.on_player_changed_force] = refresh_player_warps,
        [e.on_chart_tag_modified] = on_chart_tag_changed,
        [e.on_chart_tag_removed] = on_chart_tag_changed,
        [Roles.events.on_player_roles_changed] = refresh_player_permissions,
    },
    on_nth_tick = {
        [update_interval] = update_players,
    }
}
