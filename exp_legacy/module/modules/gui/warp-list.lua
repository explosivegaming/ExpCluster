--[[-- Gui Module - Warp List
    - Adds a warp list gui which allows players to add and remove warp points
    @gui Warps-List
    @alias warp_list
]]

local ExpUtil = require("modules/exp_util")
local Gui = require("modules/exp_gui")
local Datastore = require("modules.exp_legacy.expcore.datastore") --- @dep expcore.datastore
local Storage = require("modules/exp_util/storage")
local Event = require("modules/exp_legacy/utils/event") --- @dep utils.event
local Roles = require("modules.exp_legacy.expcore.roles") --- @dep expcore.roles
local Colors = require("modules/exp_util/include/color")
local config = require("modules.exp_legacy.config.gui.warps") --- @dep config.gui.warps
local Warps = require("modules.exp_legacy.modules.control.warps") --- @dep modules.control.warps

local format_time = ExpUtil.format_time_factory_locale{ format = "short", hours = true, minutes = true }

--- Stores all data for the warp gui
local WrapGuiData = Datastore.connect("WrapGuiData")
WrapGuiData:set_serializer(Datastore.name_serializer)
local PlayerInRange = WrapGuiData:combine("PlayerInRange")
PlayerInRange:set_default(false)
local PlayerCooldown = WrapGuiData:combine("PlayerCooldown")
PlayerCooldown:set_default(0)

--- Table that stores a boolean value of weather to keep the warp gui open
local keep_gui_open = {}
Storage.register(keep_gui_open, function(tbl)
    keep_gui_open = tbl
end)

--- Styles used for sprite buttons
local Styles = {
    sprite22 = { height = 22, width = 22, padding = -2 },
    sprite32 = { height = 32, width = 32, left_margin = 1 },
}
--- Status icon of a warp
local warp_status_icons = {
    cooldown = "[img=utility/multiplayer_waiting_icon]",
    not_available = "[img=utility/set_bar_slot]",
    bypass = "[img=utility/side_menu_bonus_icon]",
    current = "[img=utility/side_menu_map_icon]",
    connected = "[img=utility/logistic_network_panel_white]",
    different = "[img=utility/warning_white]",
}

--- Returns if a player is allowed to edit the given warp
--- If a player is allowed to use the edit buttons
local function check_player_permissions(player, action, warp)
    -- Check if the action is allow edit and then check bypass settings
    if action == "allow_edit_warp" then
        -- Check if the warp is the spawn then it cant be edited
        local spawn_id = Warps.get_spawn_warp_id(player.force.name)
        if spawn_id == warp.warp_id then
            return false
        end

        -- Check if the player being the last to edit will override existing permisisons
        if config.user_can_edit_own_warps and warp.last_edit_name == player.name then
            return true
        end
    end

    -- Check player has permission based on value in the config
    local action_config = config[action]
    if action_config == "all" then
        return true
    elseif action_config == "admin" then
        return player.admin
    elseif action_config == "expcore.roles" then
        return Roles.player_allowed(player, config["expcore_roles_" .. action])
    end

    -- Return false as all other conditions have not been met
    return false
end

--- Will add a new warp to the list, checks if the player is too close to an existing one
-- @element add_new_warp
local add_new_warp = Gui.element("add_new_warp")
    :draw{
        type = "sprite-button",
        sprite = "utility/add",
        tooltip = { "warp-list.add-tooltip" },
        style = "shortcut_bar_button",
        name = Gui.property_from_name,
    }
    :style(Styles.sprite22)
    :on_click(function(def, player, element)
        if player.controller_type ~= defines.controllers.character then return end
        -- Add the new warp
        local force_name = player.force.name
        local surface = player.physical_surface
        local position = player.physical_position

        -- Check if the warp is too close to water
        local water_tiles = surface.find_tiles_filtered{ collision_mask = "water_tile", radius = config.standard_proximity_radius + 1, position = position }
        if #water_tiles > 0 then
            player.print(
                { "expcore-commands.command-fail", { "warp-list.too-close-to-water", config.standard_proximity_radius + 1 } },
                { color = Colors.orange_red }
            )
            if game.player then game.player.play_sound{ path = "utility/wire_pickup" } end
            for _, tile in pairs(water_tiles) do
                rendering.draw_sprite{
                    sprite = "utility/rail_path_not_possible",
                    x_scale = 0.5,
                    y_scale = 0.5,
                    target = tile.position,
                    surface = surface,
                    players = { player },
                    time_to_live = 60,
                }
            end

            return
        end

        -- Check if there are player entities in the way (has a bigger radius because the enities that can be placed by a player are larger)
        local entities = surface.find_entities_filtered{
            radius = config.standard_proximity_radius + 2.5,
            position = position,
            collision_mask = {
                "item", "object", "player", "water_tile",
            },
        }
        -- Remove 1 because that is the current player
        if #entities > 1 then
            player.print(
                { "expcore-commands.command-fail", { "warp-list.too-close-to-entities", config.standard_proximity_radius + 2.5 } },
                { color = Colors.orange_red }
            )
            if game.player then game.player.play_sound{ path = "utility/wire_pickup" } end
            local character = player.character
            for _, entity in pairs(entities) do
                if entity ~= character then
                    rendering.draw_sprite{
                        sprite = "utility/rail_path_not_possible",
                        x_scale = 0.5,
                        y_scale = 0.5,
                        target = entity,
                        surface = surface,
                        players = { player },
                        time_to_live = 60,
                    }
                end
            end

            return
        end

        -- Create the warp
        local warp_id = Warps.add_warp(force_name, surface, position, player.name)
        Warps.make_warp_tag(warp_id)
        Warps.make_warp_area(warp_id)
    end)

--- Warp icon button, this will trigger a warp when the player is able to
-- @element warp_icon_button
local warp_icon_button = Gui.element("warp_icon_button")
    :draw(function(def, parent, warp)
        local warp_position = warp.position

        -- The SpritePath type is not the same as the SignalID type
        local sprite = warp.icon.type .. "/" .. warp.icon.name
        if warp.icon.type == "virtual" then
            sprite = "virtual-signal/" .. warp.icon.name
        end

        -- Draw the element
        return parent.add{
            type = "sprite-button",
            sprite = sprite,
            name = def.name,
            tooltip = { "warp-list.goto-tooltip", warp_position.x, warp_position.y },
            style = "slot_button",
        }
    end)
    :style(Styles.sprite32)
    :on_click(function(def, player, element)
        if element.type == "choose-elem-button" then return end
        local warp_id = element.parent.caption
        Warps.teleport_player(warp_id, player)

        -- Reset the warp cooldown if the player does not have unlimited warps
        if not check_player_permissions(player, "bypass_warp_cooldown") then
            PlayerCooldown:set(player, config.update_smoothing * config.cooldown_duration)
        end

        PlayerInRange:set(player, warp_id)
    end)

--- The button that is visible when the warp is in edit state
-- @element warp_icon_editing
local warp_icon_editing = Gui.element("warp_icon_editing")
    :draw(function(def, parent, warp)
        return parent.add{
            name = def.name,
            type = "choose-elem-button",
            elem_type = "signal",
            signal = { type = warp.icon.type, name = warp.icon.name },
            tooltip = { "warp-list.goto-edit" },
        }
    end)
    :style(Styles.sprite32)

--- Warp label, visible if the player is not in edit state
-- @element warp_label
local warp_label = Gui.element("warp_label")
    :draw(function(def, parent, warp)
        local last_edit_name = warp.last_edit_name
        local last_edit_time = warp.last_edit_time
        -- Draw the element
        return parent.add{
            type = "label",
            caption = warp.name,
            tooltip = { "warp-list.last-edit", last_edit_name, format_time(last_edit_time) },
            name = def.name,
        }
    end)
    :style{
        single_line = true,
        left_padding = 2,
        right_padding = 2,
        horizontally_stretchable = true,
    }
    :on_click(function(def, player, element)
        local warp_id = element.parent.caption
        local warp = Warps.get_warp(warp_id)
        player.set_controller{ type = defines.controllers.remote, position = warp.position, surface = warp.surface }
    end)

--- Warp status, visible if the player is not in edit state
--- This will show if the warp is connected or not
-- @element warp_status
local warp_status = Gui.element("warp_status")
    :draw{
        type = "label",
        caption = "[img=utility/electricity_icon_unplugged]", -- Temporary icon
        name = Gui.property_from_name,
    }
    :style{
        -- When editing mode because textbox is larger the icon would move up.
        top_padding = 1,
        single_line = false,
    }

--- Warp textfield, visible if the player is in edit state
-- @element warp_textfield
local warp_textfield = Gui.element("warp_textfield")
    :draw(function(def, parent, warp)
        -- Draw the element
        return parent.add{
            type = "textfield",
            text = warp.name,
            clear_and_focus_on_right_click = true,
            name = def.name,
        }
    end)
    :style{
        -- Required fields to make it squashable and strechable.
        minimal_width = 10,
        maximal_width = 300,
        horizontally_squashable = true,
        horizontally_stretchable = true,
        -- Other styling
        height = 22,
        padding = -2,
        left_margin = 2,
        right_margin = 2,
    }
    :on_confirmed(function(def, player, element)
        local warp_id = element.parent.caption
        local warp_name = element.text
        local warp_icon = element.parent.parent["icon-" .. warp_id][warp_icon_editing.name].elem_value --[[ @as SignalID ]]
        if warp_icon.type == nil then warp_icon.type = "item" end
        Warps.set_editing(warp_id, player.name)
        Warps.update_warp(warp_id, warp_name, warp_icon, player.name)
    end)

--- Confirms the edit to name or icon of the warp
-- @element confirm_edit_button
local confirm_edit_button = Gui.element("confirm_edit_button")
    :draw{
        type = "sprite-button",
        sprite = "utility/confirm_slot",
        tooltip = { "warp-list.confirm-tooltip" },
        style = "shortcut_bar_button_green",
        name = Gui.property_from_name,
    }
    :style(Styles.sprite22)
    :on_click(function(def, player, element)
        local warp_id = element.parent.caption
        local warp_name = element.parent.parent["name-" .. warp_id][warp_textfield.name].text
        local warp_icon = element.parent.parent["icon-" .. warp_id][warp_icon_editing.name].elem_value --[[ @as SignalID ]]
        if warp_icon.type == nil then warp_icon.type = "item" end
        Warps.set_editing(warp_id, player.name)
        Warps.update_warp(warp_id, warp_name, warp_icon, player.name)
    end)

--- Cancels the editing changes of the selected warp name or icon
-- @element cancel_edit_button
local cancel_edit_button = Gui.element("cancel_edit_button")
    :draw{
        type = "sprite-button",
        sprite = "utility/close_black",
        tooltip = { "warp-list.cancel-tooltip" },
        style = "shortcut_bar_button_red",
        name = Gui.property_from_name,
    }
    :style(Styles.sprite22)
    :on_click(function(def, player, element)
        local warp_id = element.parent.caption
        -- Check if this is the first edit, if so remove the warp.
        local warp = Warps.get_warp(warp_id)
        if warp.updates == 1 then
            Warps.remove_warp(warp_id)
            return
        end
        Warps.set_editing(warp_id, player.name)
    end)

--- Removes a warp from the list, including the physical area and map tag
-- @element remove_warp_button
local remove_warp_button = Gui.element("remove_warp_button")
    :draw{
        type = "sprite-button",
        sprite = "utility/trash",
        tooltip = { "warp-list.remove-tooltip" },
        style = "shortcut_bar_button_red",
        name = Gui.property_from_name,
    }
    :style(Styles.sprite22)
    :on_click(function(def, player, element)
        local warp_id = element.parent.caption
        Warps.remove_warp(warp_id)
    end)

--- Opens edit mode for the warp
-- @element edit_warp_button
local edit_warp_button = Gui.element("edit_warp_button")
    :draw{
        type = "sprite-button",
        sprite = "utility/rename_icon",
        tooltip = { "warp-list.edit-tooltip-none" },
        style = "shortcut_bar_button",
        name = Gui.property_from_name,
    }
    :style(Styles.sprite22)
    :on_click(function(def, player, element)
        local warp_id = element.parent.caption
        Warps.set_editing(warp_id, player.name, true)
    end)

local update_all_warp_elements
--- Set of three elements which make up each row of the warp table
-- @element add_warp_elements
local add_warp_elements = Gui.element("add_warp_elements")
    :draw(function(_, parent, warp)
        -- Add icon flow, this will contain the warp button and warp icon edit button
        local icon_flow = parent.add{
            name = "icon-" .. warp.warp_id,
            type = "flow",
            caption = warp.warp_id,
        }
        icon_flow.style.padding = 0

        -- Add the button and the icon edit button
        warp_icon_button(icon_flow, warp)
        warp_icon_editing(icon_flow, warp)

        -- Add name flow, this will contain the warp label and textbox
        local name_flow = parent.add{
            type = "flow",
            name = "name-" .. warp.warp_id,
            caption = warp.warp_id,
        }
        name_flow.style.padding = 0

        -- Add the label and textfield of the warp
        warp_status(name_flow)
        warp_label(name_flow, warp)
        warp_textfield(name_flow, warp)

        -- Add button flow, this will contain buttons to manage this specific warp
        local button_flow = parent.add{
            type = "flow",
            name = "button-" .. warp.warp_id,
            caption = warp.warp_id,
        }
        button_flow.style.padding = 0

        -- Add both edit state buttons
        confirm_edit_button(button_flow)
        cancel_edit_button(button_flow)
        edit_warp_button(button_flow)
        remove_warp_button(button_flow)
    end)

-- Removes the three elements that are added as part of the warp base
local function remove_warp_elements(parent, warp_id)
    Gui.destroy_if_valid(parent["icon-" .. warp_id])
    Gui.destroy_if_valid(parent["name-" .. warp_id])
    Gui.destroy_if_valid(parent["button-" .. warp_id])
end

--- This timer controls when a player is able to warp, eg every 60 seconds
-- @element warp_timer
local warp_timer = Gui.element("warp_timer")
    :draw{
        type = "progressbar",
        name = Gui.property_from_name,
        tooltip = { "warp-list.timer-tooltip-zero", config.cooldown_duration },
        minimum_value = 0,
        maximum_value = config.cooldown_duration * config.update_smoothing,
    }
    :style{
        horizontally_stretchable = true,
        color = Colors.light_blue,
    }

local warp_list_container

-- Helper function to style and enable or disable a button element
local function update_warp_elements(element, warp, warp_player_is_on, on_cooldown, bypass_warp_proximity)
    -- Check if button element is valid
    if not element or not element.valid then return end

    local label_style = element.parent.parent["name-" .. warp.warp_id][warp_label.name].style
    local warp_status_element = element.parent.parent["name-" .. warp.warp_id][warp_status.name]

    -- If player is not on a warp
    if not warp_player_is_on then
        -- If player is allowed to warp without being on a warp. If not then disable the warp location
        if bypass_warp_proximity then
            local position = warp.position
            element.tooltip = { "warp-list.goto-bypass", position.x, position.y }
            element.enabled = true
            warp_status_element.tooltip = { "warp-list.goto-bypass", position.x, position.y }
            warp_status_element.caption = warp_status_icons.bypass
            label_style.font = "default-semibold"
        else
            element.tooltip = { "warp-list.goto-disabled" }
            element.enabled = false
            warp_status_element.tooltip = { "warp-list.goto-disabled" }
            warp_status_element.caption = warp_status_icons.not_available
            label_style.font = "default"
        end
        -- If player is on the warp that is being updated
    elseif warp_player_is_on.warp_id == warp.warp_id then
        element.tooltip = { "warp-list.goto-same-warp" }
        element.enabled = false
        warp_status_element.tooltip = { "warp-list.goto-same-warp" }
        warp_status_element.caption = warp_status_icons.current
        label_style.font = "default"
        -- If player is on cooldown
    elseif on_cooldown then
        element.tooltip = { "warp-list.goto-cooldown" }
        element.enabled = false
        warp_status_element.tooltip = { "warp-list.goto-cooldown" }
        warp_status_element.caption = warp_status_icons.cooldown
        label_style.font = "default"
    else
        -- If the warp the player is standing on is the same as the warp that is being updated
        local warp_electric_network_id = warp.electric_pole and warp.electric_pole.electric_network_id or -1
        local player_warp_electric_network_id = warp_player_is_on.electric_pole and warp_player_is_on.electric_pole.electric_network_id or -2
        if warp_electric_network_id == player_warp_electric_network_id then
            local position = warp.position
            element.tooltip = { "warp-list.goto-tooltip", position.x, position.y }
            element.enabled = true
            warp_status_element.tooltip = { "warp-list.goto-tooltip", position.x, position.y }
            warp_status_element.caption = warp_status_icons.connected
            label_style.font = "default-semibold"
            -- If the warp is not on the same network but the player is allowed to warp without being on a warp
        elseif bypass_warp_proximity then
            local position = warp.position
            element.tooltip = { "warp-list.goto-bypass-different-network", position.x, position.y }
            element.enabled = true
            warp_status_element.tooltip = { "warp-list.goto-bypass-different-network", position.x, position.y }
            warp_status_element.caption = warp_status_icons.bypass
            label_style.font = "default-semibold"
            -- If the warp is on a different network than the one the player is standing on
        else
            element.tooltip = { "warp-list.goto-different-network" }
            element.enabled = false
            warp_status_element.tooltip = { "warp-list.goto-different-network" }
            warp_status_element.caption = warp_status_icons.different
            label_style.font = "default"
        end
    end
end

--- Update the warp buttons for a player
function update_all_warp_elements(player, timer, warp_id)
    -- Get the warp table
    local container = Gui.get_left_element(warp_list_container, player)
    local scroll_table = container.frame.scroll.table

    -- Check if the player is currently on cooldown
    timer = timer or PlayerCooldown:get(player)
    local on_cooldown = timer > 0
    -- Get the warp the player is on
    warp_id = warp_id or PlayerInRange:get(player)
    local warp_player_is_on = warp_id and Warps.get_warp(warp_id) or nil
    -- Check player permission
    local bypass_warp_proximity = check_player_permissions(player, "bypass_warp_proximity")

    -- Change the enabled state of the warp buttons
    local warp_ids = Warps.get_force_warp_ids(player.force.name)
    for _, next_warp_id in pairs(warp_ids) do
        local element = scroll_table["icon-" .. next_warp_id][warp_icon_button.name]
        local next_warp = Warps.get_warp(next_warp_id)
        update_warp_elements(element, next_warp, warp_player_is_on, on_cooldown, bypass_warp_proximity)
    end
end

--- Updates a warp for a player
local function update_warp(player, warp_table, warp_id)
    local warp = Warps.get_warp(warp_id)

    -- If the warp no longer exists then remove the warp elements from the warp table
    if not warp then
        remove_warp_elements(warp_table, warp_id)
        return
    end

    -- Create the warp elements if they do not already exist
    if not warp_table["icon-" .. warp_id] then
        add_warp_elements(warp_table, warp)
    end
    local icon_flow = warp_table["icon-" .. warp_id]
    local name_flow = warp_table["name-" .. warp_id]
    local button_flow = warp_table["button-" .. warp_id]

    -- Create local references to the elements for this warp
    local warp_icon_element = icon_flow[warp_icon_button.name]
    local warp_icon_edit_element = icon_flow[warp_icon_editing.name]

    local label_element = name_flow[warp_label.name]
    local textfield_element = name_flow[warp_textfield.name]

    local cancel_edit_element = button_flow[cancel_edit_button.name]
    local confirm_edit_element = button_flow[confirm_edit_button.name]

    local edit_warp_element = button_flow[edit_warp_button.name]
    local remove_warp_element = button_flow[remove_warp_button.name]

    -- Hide the edit button if the player is not allowed to edit the warp
    local player_allowed_edit = check_player_permissions(player, "allow_edit_warp", warp)
    local players_editing = table.get_keys(warp.currently_editing)
    edit_warp_element.visible = player_allowed_edit

    -- Set the tooltip of the edit button
    if #players_editing > 0 then
        edit_warp_element.hovered_sprite = "utility/warning_icon"
        edit_warp_element.tooltip = { "warp-list.edit-tooltip", table.concat(players_editing, ", ") }
    else
        edit_warp_element.hovered_sprite = edit_warp_element.sprite
        edit_warp_element.tooltip = { "warp-list.edit-tooltip-none" }
    end

    -- Set the visibility of the warp elements based on whether the user is editing or not
    local player_is_editing = warp.currently_editing[player.name]
    if player_is_editing then
        -- Set the icon elements visibility
        warp_icon_element.visible = false
        warp_icon_edit_element.visible = true
        -- Set the name elements visibility
        label_element.visible = false
        textfield_element.visible = true
        textfield_element.focus()
        warp_table.parent.scroll_to_element(textfield_element, "top-third")
        -- Set the edit buttons
        cancel_edit_element.visible = true
        confirm_edit_element.visible = true
        -- Set the warp buttons
        edit_warp_element.visible = false
        remove_warp_element.visible = false
    else
        -- Set the icon elements visibility
        warp_icon_element.visible = true
        -- The SpritePath type is not the same as the SignalID type
        local sprite = warp.icon.type .. "/" .. warp.icon.name
        if warp.icon.type == "virtual" then
            sprite = "virtual-signal/" .. warp.icon.name
        end
        warp_icon_element.sprite = sprite
        -- Set icon edit to the warps icon
        warp_icon_edit_element.elem_value = warp.icon
        warp_icon_edit_element.visible = false
        -- Set the name elements visibility
        label_element.visible = true
        label_element.caption = warp.name
        textfield_element.visible = false
        textfield_element.text = warp.name
        -- Set the edit buttons
        cancel_edit_element.visible = false
        confirm_edit_element.visible = false
        -- Set the warp buttons
        edit_warp_element.visible = true and player_allowed_edit
        remove_warp_element.visible = true and player_allowed_edit
    end

    local timer = PlayerCooldown:get(player)
    local current_warp_id = PlayerInRange:get(player)
    local to_warp = current_warp_id and Warps.get_warp(current_warp_id) or nil
    local bypass_warp_proximity = check_player_permissions(player, "bypass_warp_proximity")
    update_warp_elements(warp_icon_element, warp, to_warp, timer > 0, bypass_warp_proximity)
end

-- Update all the warps for a player
local function update_all_warps(player, warp_table)
    local warp_ids = Warps.get_force_warp_ids(player.force.name)
    warp_table.clear()
    for _, warp_id in ipairs(warp_ids) do
        update_warp(player, warp_table, warp_id)
    end
end

-- Update all warps for all players on a force
local function update_all_warp_force(force)
    local warp_ids = Warps.get_force_warp_ids(force.name)
    for _, player in pairs(force.connected_players) do
        local container = Gui.get_left_element(warp_list_container, player)
        local warp_table = container.frame.scroll.table

        warp_table.clear() -- Needed to re-sort the warps
        for _, warp_id in ipairs(warp_ids) do
            update_warp(player, warp_table, warp_id)
        end
    end
end

--- Main warp list container for the left flow
-- @element warp_list_container
warp_list_container = Gui.element("warp_list_container")
    :draw(function(def, parent)
        local player = Gui.get_player(parent)
        -- Check if user has permission to add warps
        local allow_add_warp = check_player_permissions(player, "allow_add_warp")

        -- Draw the internal container
        local container = Gui.elements.container(parent, allow_add_warp and 268 or 220)

        -- Draw the header
        local header = Gui.elements.header(container, {
            name = "header",
            caption = { "warp-list.main-caption" },
            tooltip = {
                "warp-list.sub-tooltip",
                config.cooldown_duration,
                config.standard_proximity_radius,
                { "warp-list.sub-tooltip-current", warp_status_icons.current },
                { "warp-list.sub-tooltip-connected", warp_status_icons.connected },
                { "warp-list.sub-tooltip-different", warp_status_icons.different },
                { "warp-list.sub-tooltip-cooldown", warp_status_icons.cooldown },
                { "warp-list.sub-tooltip-not_available", warp_status_icons.not_available },
                { "warp-list.sub-tooltip-bypass", warp_status_icons.bypass },
            },
        })

        -- Draw the new warp button
        local add_new_warp_element = add_new_warp(header)
        add_new_warp_element.visible = allow_add_warp

        -- Draw the scroll table for the warps
        local scroll_table = Gui.elements.scroll_table(container, 250, 3, "scroll")
        -- Set the scroll panel to always show the scrollbar (not doing this will result in a changing gui size)
        scroll_table.parent.vertical_scroll_policy = "always"

        -- Change the style of the scroll table
        local scroll_table_style = scroll_table.style
        scroll_table_style.top_cell_padding = 3
        scroll_table_style.bottom_cell_padding = 3

        -- Draw the warp cooldown progress bar
        local warp_timer_element = warp_timer(container)

        -- Change the progress of the warp timer
        local timer = PlayerCooldown:get(player)
        if timer > 0 then
            warp_timer_element.tooltip = { "warp-list.timer-tooltip", math.floor(timer / config.update_smoothing) }
            warp_timer_element.value = 1 - (timer / config.update_smoothing / config.cooldown_duration)
        else
            warp_timer_element.tooltip = { "warp-list.timer-tooltip-zero", config.cooldown_duration }
            warp_timer_element.value = 1
        end

        -- Add any existing warps
        update_all_warps(player, scroll_table)

        -- Return the external container
        return container.parent
    end)

--- Add the element to the left flow with a toolbar button
Gui.add_left_element(warp_list_container, false)
Gui.toolbar.create_button{
    name = "warp_list_toggle",
    left_element = warp_list_container,
    sprite = config.default_icon.type .. "/" .. config.default_icon.name,
    tooltip = { "warp-list.main-tooltip" },
    visible = function(player, element)
        return Roles.player_allowed(player, "gui/warp-list")
    end
}:on_click(function(def, player, element)
    -- Set gui keep open state for player that clicked the button: true if visible, false if invisible
    keep_gui_open[player.name] = Gui.toolbar.get_button_toggled_state(def, player)
end)

--- When the name of a warp is updated this is triggered
Warps.on_update(function(_, warp, old_warp)
    -- Get the force to update, warp is nil when removed
    if warp then
        update_all_warp_force(game.forces[warp.force_name])
    else
        update_all_warp_force(game.forces[old_warp.force_name])
    end
end)

--- When the player leaves or enters range of a warp this is triggered
PlayerInRange:on_update(function(player_name, warp_id)
    local player = game.players[player_name]

    -- Change if the frame is visible based on if the player is in range
    if not keep_gui_open[player.name] then
        Gui.toolbar.set_left_element_visible_state(warp_list_container, player, warp_id ~= nil)
    end

    update_all_warp_elements(player, nil, warp_id)
end)

--- Update the warp cooldown progress bars to match the current cooldown
PlayerCooldown:on_update(function(player_name, player_cooldown)
    -- Get the progress bar element
    local player = game.players[player_name]
    local container = Gui.get_left_element(warp_list_container, player)
    local warp_timer_element = container.frame[warp_timer.name]

    -- Set the progress
    if player_cooldown and player_cooldown > 0 then
        warp_timer_element.tooltip = { "warp-list.timer-tooltip", math.floor(player_cooldown / config.update_smoothing) }
        warp_timer_element.value = 1 - (player_cooldown / config.update_smoothing / config.cooldown_duration)
    else
        warp_timer_element.tooltip = { "warp-list.timer-tooltip-zero", config.cooldown_duration }
        warp_timer_element.value = 1
    end

    -- Trigger update of buttons if cooldown is now 0
    if player_cooldown == 0 then
        update_all_warp_elements(player, player_cooldown, nil)
    end
end)

--- Handles updating the timer and checking distance from a warp
local r2 = config.standard_proximity_radius ^ 2
local rs2 = config.spawn_proximity_radius ^ 2
local mr2 = config.minimum_distance ^ 2
Event.on_nth_tick(math.floor(60 / config.update_smoothing), function()
    PlayerCooldown:update_all(function(_, player_cooldown)
        if player_cooldown > 0 then return player_cooldown - 1 end
    end)

    local force_warps = {}
    local warps = {}
    for _, player in pairs(game.connected_players) do
        local was_in_range = PlayerInRange:get(player)

        -- Get the ids of all the warps on the players force
        local force_name = player.force.name
        local warp_ids = force_warps[force_name]
        if not warp_ids then
            warp_ids = Warps.get_force_warp_ids(force_name)
            force_warps[force_name] = warp_ids
        end

        -- Check if the force has any warps
        local closest_warp = nil
        local closest_distance = nil
        if #warp_ids > 0 then
            local surface = player.surface
            local pos = player.physical_position
            local px, py = pos.x, pos.y

            -- Loop over each warp
            for _, warp_id in ipairs(warp_ids) do
                -- Check if warp id is cached
                local warp = warps[warp_id]
                if not warp then
                    warp = Warps.get_warp(warp_id)
                    warps[warp_id] = warp
                end

                -- Check if the player is within range
                local warp_pos = warp.position
                if warp.surface == surface then
                    local dx, dy = px - warp_pos.x, py - warp_pos.y
                    local dist = (dx * dx) + (dy * dy)
                    if closest_distance == nil or dist < closest_distance then
                        closest_warp = warp
                        closest_distance = dist
                        if dist < r2 then break end
                    end
                end
            end

            -- Check the dist to the closest warp
            local in_range = closest_warp ~= nil and (closest_warp.warp_id == warp_ids.spawn and closest_distance < rs2 or closest_distance < r2)
            if was_in_range and not in_range then
                PlayerInRange:set(player, nil)
            elseif not was_in_range and in_range then
                --- @cast closest_warp -nil
                PlayerInRange:set(player, closest_warp.warp_id)
            end

            -- Change the enabled state of the add warp button
            local container = Gui.get_left_element(warp_list_container, player)
            local add_warp_element = container.frame.header.flow[add_new_warp.name]
            local old_closest_warp_name = add_warp_element.tooltip[2] or closest_warp and closest_warp.name
            local was_able_to_make_warp = add_warp_element.enabled
            local can_make_warp = closest_distance == nil or closest_distance > mr2
            if can_make_warp and not was_able_to_make_warp then
                add_warp_element.enabled = true
                add_warp_element.tooltip = { "warp-list.add-tooltip" }
            elseif not can_make_warp and was_able_to_make_warp or closest_warp and (old_closest_warp_name ~= closest_warp.name) then
                --- @cast closest_warp -nil
                add_warp_element.enabled = false
                add_warp_element.tooltip = { "warp-list.too-close", closest_warp.name }
            end
        end
    end
end)

--- When a player is created make sure that there is a spawn warp created
Event.add(defines.events.on_player_created, function(event)
    -- If the force has no spawn then make a spawn warp
    local player = game.players[event.player_index]
    local force = player.force
    local spawn_id = Warps.get_spawn_warp_id(force.name)
    if not spawn_id then
        local spawn_position = force.get_spawn_position(player.surface)
        spawn_id = Warps.add_warp(force.name, player.surface, spawn_position, nil, "Spawn")
        Warps.set_spawn_warp(spawn_id, force)
        Warps.make_warp_tag(spawn_id)

        local entities = player.surface.find_entities_filtered{ type = "electric-pole", position = spawn_position, radius = 20, limit = 1 }
        if entities and entities[1] then
            local warp = Warps.get_warp(spawn_id)
            warp.electric_pole = entities[1]
        end
    end
end)

--- Update the warps when the player joins
Event.add(defines.events.on_player_joined_game, function(event)
    local player = game.players[event.player_index]
    local container = Gui.get_left_element(warp_list_container, player)
    local scroll_table = container.frame.scroll.table
    update_all_warps(player, scroll_table)
end)

--- Makes sure the right buttons are present when roles change
local function role_update_event(event)
    local player = game.players[event.player_index]
    local frame = Gui.get_left_element(warp_list_container, player).frame

    -- Check if user has permission to add warps
    local allow_add_warp = check_player_permissions(player, "allow_add_warp")
    -- Update container size depending on whether the player is allowed to add warps
    frame.parent.style.width = allow_add_warp and 268 or 220

    -- Update the warps, in case the user can now edit them
    local scroll_table = frame.scroll.table
    update_all_warps(player, scroll_table)

    -- Update the new warp button in case the user can now add them
    local add_new_warp_element = frame.header.flow[add_new_warp.name]
    add_new_warp_element.visible = allow_add_warp
end

Event.add(Roles.events.on_role_assigned, role_update_event)
Event.add(Roles.events.on_role_unassigned, role_update_event)

--- When a chart tag is removed or edited make sure it is not one that belongs to a warp
local function maintain_tag(event)
    if not event.player_index then return end
    local tag = event.tag
    local force_name = event.force.name
    local warp_ids = Warps.get_force_warp_ids(force_name)
    for _, warp_id in pairs(warp_ids) do
        local warp = Warps.get_warp(warp_id)
        local warp_tag = warp.tag
        if not warp_tag or not warp_tag.valid or warp_tag == tag then
            if event.name == defines.events.on_chart_tag_removed then
                warp.tag = nil
            end
            Warps.make_warp_tag(warp_id)
        end
    end
end

Event.add(defines.events.on_chart_tag_modified, maintain_tag)
Event.add(defines.events.on_chart_tag_removed, maintain_tag)
