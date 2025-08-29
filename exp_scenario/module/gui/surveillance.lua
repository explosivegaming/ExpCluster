--[[-- Gui - Surveillance
Adds cameras which can be used to view players and locations
]]

local Gui = require("modules/exp_gui")
local ElementsExtra = require("modules/exp_scenario/gui/elements")
local Roles = require("modules/exp_legacy/expcore/roles")

--- @class ExpGui_Surveillance.elements
local Elements = {}

--- Dropdown which sets the target of a camera to a player
--- @class ExpGui_Surveillance.elements.player_dropdown: ExpElement
--- @field data table<LuaGuiElement, LuaGuiElement>
--- @overload fun(parent: LuaGuiElement, camera: LuaGuiElement): LuaGuiElement
Elements.player_dropdown = Gui.define("surveillance/player_dropdown")
    :draw(function(def, parent)
        return ElementsExtra.online_player_dropdown(parent)
    end)
    :element_data(
        Gui.from_argument(1)
    )
    :on_selection_state_changed(function(def, player, element, event)
        --- @cast def ExpGui_Surveillance.elements.player_dropdown
        local camera = def.data[element]
        local target_player = assert(ElementsExtra.online_player_dropdown.get_selected(element))
        Elements.camera.set_target_player(camera, target_player)
    end) --[[ @as any ]]

--- Button which sets the target of a camera to the current location
--- @class ExpGui_Surveillance.elements.set_location_button: ExpElement
--- @field data table<LuaGuiElement, LuaGuiElement>
--- @overload fun(parent: LuaGuiElement, camera: LuaGuiElement): LuaGuiElement
Elements.set_location_button = Gui.define("surveillance/set_location_button")
    :draw{
        type = "button",
        caption = { "exp-gui_surveillance.caption-set-location" },
        visible = false,
    }
    :style{
        width = 48,
        height = 24,
    }
    :element_data(
        Gui.from_argument(1)
    )
    :on_click(function(def, player, element)
        --- @cast def ExpGui_Surveillance.elements.set_location_button
        local camera = def.data[element]
        Elements.camera.set_target_position(camera, player.physical_surface_index, player.physical_position)
    end) --[[ @as any ]]

--- @class ExpGui_Surveillance.elements.type_dropdown.data
--- @field player_dropdown LuaGuiElement
--- @field location_button LuaGuiElement
--- @field camera LuaGuiElement

--- Selects the type of camera to display, actually just controls the visible buttons
--- @class ExpGui_Surveillance.elements.type_dropdown: ExpElement
--- @field data table<LuaGuiElement, ExpGui_Surveillance.elements.type_dropdown.data>
--- @overload fun(parent: LuaGuiElement, data: ExpGui_Surveillance.elements.type_dropdown.data): LuaGuiElement
Elements.type_dropdown = Gui.define("surveillance/type_dropdown")
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
    :element_data(
        Gui.from_argument(1)
    )
    :on_selection_state_changed(function(def, player, element, event)
        --- @cast def ExpGui_Surveillance.elements.type_dropdown
        local element_data = def.data[element]
        local selected_index = element.selected_index
        element_data.player_dropdown.visible = selected_index == 1
        element_data.location_button.visible = selected_index == 2
        if selected_index == 2 then
            -- Static is selected
            Elements.camera.set_target_position(element_data.camera, player.physical_surface_index, player.physical_position)
        else
            -- Player or loop is selected
            local target_player = ElementsExtra.online_player_dropdown.get_selected(element_data.player_dropdown)
            Elements.camera.set_target_player(element_data.camera, target_player)
        end
    end) --[[ @as any ]]

--- Refresh all online type dropdowns by cycling the associated player dropdown
function Elements.type_dropdown.refresh_online()
    local player_count = ElementsExtra.online_player_dropdown.get_player_count()
    for _, type_dropdown in Elements.type_dropdown:online_elements() do
        if type_dropdown.selected_index == 3 then
            -- Loop is selected
            local element_data = Elements.type_dropdown.data[type_dropdown]
            local player_dropdown = element_data.player_dropdown
            if player_dropdown.selected_index < player_count then
                player_dropdown.selected_index = player_dropdown.selected_index + 1
            else
                player_dropdown.selected_index = 1
            end
            local target_player = ElementsExtra.online_player_dropdown.get_selected(player_dropdown)
            Elements.camera.set_target_player(element_data.camera, target_player)
        end
    end
end

--- Buttons which decreases zoom by 5%
--- @class ExpGui_Surveillance.elements.zoom_out_button: ExpElement
--- @field data table<LuaGuiElement, LuaGuiElement>
--- @overload fun(parent: LuaGuiElement, camera: LuaGuiElement): LuaGuiElement
Elements.zoom_out_button = Gui.define("surveillance/zoom_out_button")
    :draw{
        type = "sprite-button",
        sprite = "utility/controller_joycon_back", -- -
        style = "frame_action_button",
    }
    :style{
        height = 24,
        width = 24,
    }
    :element_data(
        Gui.from_argument(1)
    )
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
Elements.zoom_in_button = Gui.define("surveillance/zoom_in_button")
    :draw{
        type = "sprite-button",
        sprite = "utility/controller_joycon_start", -- +
        style = "frame_action_button",
    }
    :style{
        height = 24,
        width = 24,
    }
    :element_data(
        Gui.from_argument(1)
    )
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
Elements.camera = Gui.define("surveillance/camera")
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
    :element_data(
        Gui.from_argument(1)
    ) --[[ @as any ]]

--- Set the target player for the camera
--- @param camera LuaGuiElement
--- @param player LuaPlayer
function Elements.camera.set_target_player(camera, player)
    Elements.camera.data[camera] = player
end

--- Set the target position for the camera
--- @param camera LuaGuiElement
--- @param surface_index number
--- @param position MapPosition
function Elements.camera.set_target_position(camera, surface_index, position)
    Elements.camera.data[camera] = nil
    camera.surface_index = surface_index
    camera.position = position
end

--- Refresh the position for all cameras targeting a player
function Elements.camera.refresh_online()
    for _, camera in Elements.camera:online_elements() do
        local target_player = Elements.camera.data[camera]
        if target_player then
            camera.position = target_player.physical_position
            camera.surface_index = target_player.physical_surface_index
        end
    end
end

--- Container added to the screen
Elements.container = Gui.define("surveillance/container")
    :draw(function(def, parent)
        local screen_frame = Gui.elements.screen_frame(parent, nil, true)
        local button_flow = Gui.elements.screen_frame.get_button_flow(screen_frame)

        local target_player = Gui.get_player(parent)
        local camera = Elements.camera(screen_frame, target_player)

        local type_dropdown_data = {
            camera = camera,
            player_dropdown = Elements.player_dropdown(button_flow, camera),
            location_button = Elements.set_location_button(button_flow, camera),
        }

        Elements.type_dropdown(button_flow, type_dropdown_data)
        Elements.zoom_out_button(button_flow, camera)
        Elements.zoom_in_button(button_flow, camera)

        return Gui.elements.screen_frame.get_root_element(screen_frame)
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

local e = defines.events

return {
    elements = Elements,
    events = {
        [e.on_tick] = Elements.camera.refresh_online,
    },
    on_nth_tick = {
        [600] = Elements.type_dropdown.refresh_online,
    }
}
