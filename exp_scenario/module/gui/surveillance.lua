--[[ Gui - Surveillance
Adds cameras which can be used to view players and locations
]]

local Gui = require("modules/exp_gui")
local GuiElements = require("modules/exp_scenario/gui/elements")
local Roles = require("modules/exp_legacy/expcore/roles")

local online_player_names = GuiElements.online_player_dropdown.player_names

--- @class ExpGui_Surveillance.elements
local Elements = {}

--- Dropdown which sets the target of a camera to a player
--- @class ExpGui_Surveillance.elements.player_dropdown: ExpElement
--- @field data table<LuaGuiElement, LuaGuiElement>
--- @overload fun(parent: LuaGuiElement, camera: LuaGuiElement): LuaGuiElement
Elements.player_dropdown = Gui.element("surveillance/player_dropdown")
    :draw(function(def, parent)
        return GuiElements.online_player_dropdown(parent)
    end)
    :element_data(Gui.property_from_arg(1))
    :on_selection_state_changed(function(def, player, element, event)
        --- @cast def ExpGui_Surveillance.elements.player_dropdown
        local camera = def.data[element]
        local target_player_name = online_player_names[element.selected_index]
        Elements.camera.data[camera] = game.get_player(target_player_name)
    end) --[[ @as any ]]

--- Button which sets the target of a camera to the current location
--- @class ExpGui_Surveillance.elements.set_location_button: ExpElement
--- @field data table<LuaGuiElement, LuaGuiElement>
--- @overload fun(parent: LuaGuiElement, camera: LuaGuiElement): LuaGuiElement
Elements.set_location_button = Gui.element("surveillance/set_location_button")
    :draw{
        type = "button",
        name = Gui.property_from_name,
        caption = { "exp-gui_surveillance.label-set-location" },
        visible = false,
    }
    :style{
        width = 48,
        height = 24,
    }
    :element_data(Gui.property_from_arg(1))
    :on_click(function(def, player, element)
        --- @cast def ExpGui_Surveillance.elements.set_location_button
        local camera = def.data[element]
        Elements.camera.data[camera] = nil
        camera.position = player.physical_position
        camera.surface_index = player.physical_surface_index
    end) --[[ @as any ]]

--- @class ExpGui_Surveillance.elements.type_dropdown.data
--- @field player_dropdown LuaGuiElement
--- @field location_button LuaGuiElement
--- @field camera LuaGuiElement

--- Selects the type of camera to display, actually just controls the visible buttons
--- @class ExpGui_Surveillance.elements.type_dropdown: ExpElement
--- @field data table<LuaGuiElement, ExpGui_Surveillance.elements.type_dropdown.data>
--- @overload fun(parent: LuaGuiElement, data: ExpGui_Surveillance.elements.type_dropdown.data): LuaGuiElement
Elements.type_dropdown = Gui.element("surveillance/type_dropdown")
    :track_all_elements()
    :draw{
        type = "drop-down",
        items = { { "exp-gui_surveillance.type-player" }, { "exp-gui_surveillance.type-static" }, { "exp-gui_surveillance.type-loop" } },
        selected_index = 1,
    }
    :style{
        width = 96,
        height = 24,
    }
    :element_data(Gui.property_from_arg(1))
    :on_selection_state_changed(function(def, player, element, event)
        --- @cast def ExpGui_Surveillance.elements.type_dropdown
        local data = def.data[element]
        local selected_index = element.selected_index
        data.player_dropdown.visible = selected_index == 1
        data.location_button.visible = selected_index == 2
        if selected_index == 2 then
            -- Static is selected
            Elements.camera.data[data.camera] = nil
            data.camera.position = player.physical_position
            data.camera.surface_index = player.physical_surface_index
        else
            -- Player or loop is selected
            local player_dropdown = data.player_dropdown
            local target_player_name = online_player_names[player_dropdown.selected_index]
            if not target_player_name then
                player_dropdown.selected_index = 1
                target_player_name = online_player_names[1]
            end
            Elements.camera.data[data.camera] = game.get_player(target_player_name)
        end
    end) --[[ @as any ]]


--- Buttons which decreases zoom by 5%
--- @class ExpGui_Surveillance.elements.zoom_out_button: ExpElement
--- @field data table<LuaGuiElement, LuaGuiElement>
--- @overload fun(parent: LuaGuiElement, camera: LuaGuiElement): LuaGuiElement
Elements.zoom_out_button = Gui.element("surveillance/zoom_out_button")
    :draw{
        type = "sprite-button",
        sprite = "utility/controller_joycon_back", -- -
        style = "frame_action_button",
    }
    :style{
        height = 24,
        width = 24,
    }
    :element_data(Gui.property_from_arg(1))
    :on_click(function(def, player, element)
        --- @cast def ExpGui_Surveillance.elements.zoom_out_button
        local camera = def.data[element]
        if camera.zoom > 0.2 then
            camera.zoom = camera.zoom - 0.05
        end
    end) --[[ @as any ]]

--- Buttons which increases zoom by 5%
--- @class ExpGui_Surveillance.elements.zoom_in_button: ExpElement
--- @field data table<LuaGuiElement, LuaGuiElement>
--- @overload fun(parent: LuaGuiElement, camera: LuaGuiElement): LuaGuiElement
Elements.zoom_in_button = Gui.element("surveillance/zoom_in_button")
    :draw{
        type = "sprite-button",
        sprite = "utility/controller_joycon_start", -- +
        style = "frame_action_button",
    }
    :style{
        height = 24,
        width = 24,
    }
    :element_data(Gui.property_from_arg(1))
    :on_click(function(def, player, element)
        --- @cast def ExpGui_Surveillance.elements.zoom_in_button
        local camera = def.data[element]
        if camera.zoom < 2.0 then
            camera.zoom = camera.zoom + 0.05
        end
    end) --[[ @as any ]]

--- Camera which tracks a target with a physical_position and surface_index
--- @class ExpGui_Surveillance.elements.camera: ExpElement
--- @field data table<LuaGuiElement, LuaPlayer?>
--- @overload fun(parent: LuaGuiElement, target: LuaPlayer?): LuaGuiElement
Elements.camera = Gui.element("surveillance/camera")
    :track_all_elements()
    :draw{
        type = "camera",
        position = { x = 0, y = 0 },
        surface_index = 1,
        zoom = 0.75,
    }
    :style{
        width = 480,
        height = 290,
    }
    :element_data(Gui.property_from_arg(1)) --[[ @as any ]]

--- Container added to the screen
Elements.container = Gui.element("surveillance/container")
    :draw(function(def, parent)
        local container = Gui.elements.screen_frame(parent, nil, true)
        local button_flow = Gui.elements.screen_frame.data[container.parent]

        local target_player_name = online_player_names[1]
        local camera = Elements.camera(container, assert(game.get_player(target_player_name)))
        camera.style.width = 480
        camera.style.height = 290

        local type_data = {
            camera = camera,
            player_dropdown = Elements.player_dropdown(button_flow, camera),
            location_button = Elements.set_location_button(button_flow, camera),
        }

        Elements.type_dropdown(button_flow, type_data)
        Elements.zoom_out_button(button_flow, camera)
        Elements.zoom_in_button(button_flow, camera)

        return container.parent
    end)

--- Add a button to create the container
Gui.toolbar.create_button{
    name = "open_surveillance",
    sprite = "entity/radar",
    tooltip = { "exp-gui_surveillance.tooltip-main" },
    visible = function(player, element)
        return Roles.player_allowed(player, "gui/surveillance")
    end
}:on_click(function(def, player, element, event)
    Elements.container(player.gui.screen)
end)

--- Update the position and surface of all cameras with a player target
local function update_camera_positions()
    for _, element in Elements.camera:online_elements() do
        local target = Elements.camera.data[element]
        if target then
            -- Target is valid
            element.position = target.physical_position
            element.surface_index = target.physical_surface_index
        end
    end
end

--- Cycle to the next player for all cameras set to loop mode
local function cycle_selected_player()
    local player_count = #online_player_names
    for _, element in Elements.type_dropdown:online_elements() do
        if element.selected_index == 3 then
            -- Loop is selected
            local data = Elements.type_dropdown.data[element]
            local player_dropdown = data.player_dropdown
            if player_dropdown.selected_index < player_count then
                player_dropdown.selected_index = player_dropdown.selected_index + 1
            else
                player_dropdown.selected_index = 1
            end
            local target_player_name = online_player_names[player_dropdown.selected_index]
            Elements.camera.data[data.camera] = game.get_player(target_player_name)
        end
    end
end

local e = defines.events

return {
    elements = Elements,
    events = {
        [e.on_tick] = update_camera_positions,
    },
    on_nth_tick = {
        [600] = cycle_selected_player,
    }
}
