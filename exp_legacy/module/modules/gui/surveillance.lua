---- module surveillance
-- @gui surveillance

local Gui = require("modules/exp_gui")
local Roles = require("modules.exp_legacy.expcore.roles") --- @dep expcore.roles
local Event = require("modules/exp_legacy/utils/event") --- @dep utils.event

local cctv_player = Gui.element("cctv_player")
    :draw(function(def, parent, player_list)
        return parent.add{
            name = def.name,
            type = "drop-down",
            items = player_list,
            selected_index = #player_list > 0 and 1 or nil,
        }
    end)
    :style{
        horizontally_stretchable = true,
    }

local cctv_status = Gui.element("cctv_status")
    :draw{
        type = "drop-down",
        items = { { "surveillance.status-enable" }, { "surveillance.status-disable" } },
        selected_index = 2,
    }:style{
        width = 96,
    }:on_selection_state_changed(function(def, player, element)
        if element.selected_index == 1 then
            element.parent.parent.parent.cctv_display.visible = true
        else
            element.parent.parent.parent.cctv_display.visible = false
        end
    end)

local cctv_type = Gui.element("cctv_type")
    :draw{
        type = "drop-down",
        name = Gui.property_from_name,
        items = { { "surveillance.type-player" }, { "surveillance.type-static" }, { "surveillance.type-player-loop" } },
        selected_index = 1,
    }:style{
        width = 96,
    }

local cctv_location = Gui.element("cctv_location")
    :draw{
        type = "button",
        name = Gui.property_from_name,
        caption = { "surveillance.func-set" },
    }:style{
        width = 48,
    }:on_click(function(def, player, element)
        element.parent.parent.parent.cctv_display.position = player.physical_position
    end)

local zoom_in = Gui.element("zoom_in")
    :draw{
        type = "button",
        name = Gui.property_from_name,
        caption = "+",
    }:style{
        width = 32,
    }:on_click(function(def, player, element)
        local display = element.parent.parent.parent.cctv_display
        if display.zoom < 2.0 then
            display.zoom = display.zoom + 0.05
        end
    end)

local zoom_out = Gui.element("zoom_out")
    :draw{
        type = "button",
        name = Gui.property_from_name,
        caption = "-",
    }:style{
        width = 32,
    }:on_click(function(def, player, element)
        local display = element.parent.parent.parent.cctv_display
        if display.zoom > 0.2 then
            display.zoom = display.zoom - 0.05
        end
    end)

local camera_set = Gui.element("camera_set")
    :draw(function(_, parent, name, player_list)
        local camera_set = parent.add{ type = "flow", direction = "vertical", name = name }
        local buttons = Gui.elements.scroll_table(camera_set, 480, 6, "buttons")

        cctv_player(buttons, player_list)
        cctv_status(buttons)
        cctv_type(buttons)
        cctv_location(buttons)
        zoom_out(buttons)
        zoom_in(buttons)

        local camera = camera_set.add{
            type = "camera",
            name = "cctv_display",
            position = { x = 0, y = 0 },
            surface_index = game.surfaces["nauvis"].index,
            zoom = 0.75,
        }

        camera.visible = false
        camera.style.minimal_width = 480
        camera.style.minimal_height = 290
        return camera_set
    end)

local cctv_container = Gui.element("cctv_container")
    :draw(function(def, parent)
        local container = Gui.elements.container(parent, 480)
        local scroll = container.add{ name = "scroll", type = "scroll-pane", direction = "vertical" }
        scroll.style.maximal_height = 704
        local player_list = {}

        for _, player in pairs(game.connected_players) do
            table.insert(player_list, player.name)
        end

        camera_set(scroll, "cctv_st_1", player_list)
        camera_set(scroll, "cctv_st_2", player_list)

        return container.parent
    end)

--- Add the element to the left flow with a toolbar button
Gui.add_left_element(cctv_container, false)
Gui.toolbar.create_button{
    name = "cctv_toggle",
    left_element = cctv_container,
    sprite = "entity/radar",
    tooltip = { "surveillance.main-tooltip" },
    visible = function(player, element)
        return Roles.player_allowed(player, "gui/surveillance")
    end
}

local function gui_update()
    local player_list = {}

    for _, player in pairs(game.connected_players) do
        table.insert(player_list, player.name)
    end

    for _, player in pairs(game.connected_players) do
        local container = Gui.get_left_element(cctv_container, player)
        container.frame.scroll["cctv_st_1"].buttons.table[cctv_player.name].items = player_list
        container.frame.scroll["cctv_st_2"].buttons.table[cctv_player.name].items = player_list
    end
end

Event.add(defines.events.on_player_joined_game, gui_update)
Event.add(defines.events.on_player_left_game, gui_update)

Event.add(defines.events.on_tick, function(_)
    for _, player in pairs(game.connected_players) do
        local container = Gui.get_left_element(cctv_container, player)

        for i = 1, 2 do
            local scroll_table_name = "cctv_st_" .. i
            local current_camera_set = container.frame.scroll[scroll_table_name]
            local switch_index = current_camera_set.buttons.table[cctv_type.name].selected_index

            if (switch_index == 1) or (switch_index == 3) then
                local selected_index = current_camera_set.buttons.table[cctv_player.name].selected_index

                if selected_index ~= 0 then
                    selected_index = current_camera_set.buttons.table[cctv_player.name].items[selected_index] --[[ @as number ]]
                    current_camera_set["cctv_display"].position = game.players[selected_index].physical_position
                    current_camera_set["cctv_display"].surface_index = game.players[selected_index].surface_index
                else
                    current_camera_set["cctv_display"].position = { x = 0, y = 0 }
                    current_camera_set["cctv_display"].surface_index = game.surfaces["nauvis"].index
                end
            end
        end
    end
end)

Event.on_nth_tick(600, function(_)
    for _, player in pairs(game.connected_players) do
        local container = Gui.get_left_element(cctv_container, player)

        for i = 1, 2 do
            local current_camera_set = container.frame.scroll["cctv_st_" .. i]

            if current_camera_set.buttons.table[cctv_type.name].selected_index == 3 then
                local item_n = #current_camera_set.buttons.table[cctv_player.name].items

                if item_n ~= 0 then
                    if current_camera_set.buttons.table[cctv_player.name].selected_index < item_n then
                        current_camera_set.buttons.table[cctv_player.name].selected_index = current_camera_set.buttons.table[cctv_player.name].selected_index + 1
                    else
                        current_camera_set.buttons.table[cctv_player.name].selected_index = 1
                    end
                end
            end
        end
    end
end)
