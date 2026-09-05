--[[-- Gui - Virtual Layer
Shows what the virtual layer holds and lets players build and remove its interfaces
]]

local Gui = require("modules/exp_gui")
local Roles = require("modules/exp_roles")
local Colors = require("modules/exp_util/include/color")
local config = require("modules.exp_legacy.config.vlayer")
local Vlayer = require("modules/exp_scenario/control/vlayer")
local format_number = require("util").format_number

local Selection = require("modules/exp_util/selection")
local SelectArea = Selection.connect("ExpGui_Vlayer")

local floor = math.floor
local ceil = math.ceil
local max = math.max
local format_string = string.format

--- @class ExpGui_Vlayer.elements
local Elements = {}

--- Interface types in the order the type dropdown lists them
local interface_types = { "energy", "circuit", "storage_input", "storage_output" } --- @type ExpScenario_Vlayer.InterfaceType[]

--- Locale key of each interface type
local type_captions = {} --- @type table<ExpScenario_Vlayer.InterfaceType, LocalisedString>
for _, interface_type in ipairs(interface_types) do
    type_captions[interface_type] = { "exp-gui_vlayer.type-" .. interface_type:gsub("_", "-") }
end

--- Statistics shown as progress bars, in display order
--- @type { name: string, caption: LocalisedString, tooltip: LocalisedString }[]
local stats = {}
for _, name in ipairs{ "solar", "accumulator", "surface-area", "sustained", "production", "capacity" } do
    stats[#stats + 1] = {
        name = name,
        caption = { "exp-gui_vlayer.caption-stat-" .. name },
        tooltip = { "exp-gui_vlayer.tooltip-stat-" .. name },
    }
end

local energy_suffixes = {
    { 1e15, "P" }, { 1e12, "T" }, { 1e9, "G" }, { 1e6, "M" }, { 1e3, "k" },
}

--- Format an amount of energy with an SI prefix, util.format_number uses B for giga
--- @param amount number
--- @param unit string
--- @return string
local function format_energy(amount, unit)
    if amount < 1 then
        return "0 " .. unit
    end
    for _, suffix in ipairs(energy_suffixes) do
        if amount >= suffix[1] then
            return format_string("%.1f %s%s", amount / suffix[1], suffix[2], unit)
        end
    end
    return format_number(floor(amount), false) .. " " .. unit
end

--- Expand an area to whole tiles
--- @param area BoundingBox
--- @return BoundingBox
local function expand_area(area)
    return {
        left_top = { x = floor(area.left_top.x), y = floor(area.left_top.y) },
        right_bottom = { x = ceil(area.right_bottom.x), y = ceil(area.right_bottom.y) },
    }
end

--- Rich text link to a position
--- @param position MapPosition
--- @param surface LuaSurface
--- @return string
local function gps_string(position, surface)
    return format_string("[gps=%.1f,%.1f,%s]", position.x, position.y, surface.name)
end

--- Label naming a statistic
--- @class ExpGui_Vlayer.elements.stat_label: ExpElement
--- @overload fun(parent: LuaGuiElement, caption: LocalisedString, tooltip: LocalisedString): LuaGuiElement
Elements.stat_label = Gui.define("vlayer/stat_label")
    :draw{
        type = "label",
        caption = Gui.from_argument(1),
        tooltip = Gui.from_argument(2),
        style = "heading_2_label",
    }
    :style{
        width = 200,
    } --[[@as any]]

--- Bar showing a statistic as a fraction with the values as its caption
--- @class ExpGui_Vlayer.elements.stat_bar: ExpElement
--- @overload fun(parent: LuaGuiElement): LuaGuiElement
Elements.stat_bar = Gui.define("vlayer/stat_bar")
    :draw{
        type = "progressbar",
        caption = "",
        value = 0,
        style = "electric_satisfaction_statistics_progressbar",
    }
    :style{
        width = 200,
        font = "heading-2",
    } --[[@as any]]

--- @class ExpGui_Vlayer.elements.stat_bar.display_data
--- @field value number Fraction the bar is filled
--- @field caption string

--- Refresh a bar
--- @param stat_bar LuaGuiElement
--- @param display_data ExpGui_Vlayer.elements.stat_bar.display_data
function Elements.stat_bar.refresh(stat_bar, display_data)
    stat_bar.value = display_data.value
    stat_bar.caption = display_data.caption
end

--- Table of a label and bar for each statistic
--- @class ExpGui_Vlayer.elements.stats_table: ExpElement
--- @field data table<LuaGuiElement, table<string, LuaGuiElement>> Bars keyed by statistic name
--- @overload fun(parent: LuaGuiElement): LuaGuiElement
Elements.stats_table = Gui.define("vlayer/stats_table")
    :track_all_elements()
    :draw(function(def, parent)
        --- @cast def ExpGui_Vlayer.elements.stats_table
        local stats_table = Gui.elements.scroll_table(parent, 400, 2, "stats")
        local stat_bars = {}
        for _, stat in ipairs(stats) do
            Elements.stat_label(stats_table, stat.caption, stat.tooltip)
            stat_bars[stat.name] = Elements.stat_bar(stats_table)
        end
        def.data[stats_table] = stat_bars
        return stats_table
    end) --[[@as any]]

--- Calculate the display data of every statistic, the same for every player
--- @return table<string, ExpGui_Vlayer.elements.stat_bar.display_data>
function Elements.stats_table.calculate_display_data()
    local statistics = Vlayer.get_statistics()
    local items = Vlayer.get_items()
    local allocated = Vlayer.get_allocated_items()
    return {
        solar = {
            value = allocated["solar-panel"] / max(items["solar-panel"], 1),
            caption = format_number(allocated["solar-panel"], false) .. " / " .. format_number(items["solar-panel"], false),
        },
        accumulator = {
            value = allocated["accumulator"] / max(items["accumulator"], 1),
            caption = format_number(allocated["accumulator"], false) .. " / " .. format_number(items["accumulator"], false),
        },
        ["surface-area"] = {
            value = statistics.total_surface_area / max(statistics.surface_area, 1),
            caption = format_number(statistics.remaining_surface_area, false),
        },
        sustained = {
            value = statistics.energy_sustained / max(statistics.energy_total_production, 1),
            caption = format_energy(statistics.energy_sustained, "W") .. " / " .. format_energy(statistics.energy_total_production, "W"),
        },
        production = {
            value = statistics.energy_production / max(statistics.energy_max, 1),
            caption = format_energy(statistics.energy_production, "W") .. " / " .. format_energy(statistics.energy_max, "W"),
        },
        capacity = {
            value = statistics.energy_storage / max(statistics.energy_capacity, 1),
            caption = format_energy(statistics.energy_storage, "J") .. " / " .. format_energy(statistics.energy_capacity, "J"),
        },
    }
end

--- Refresh every bar of a table
--- @param stats_table LuaGuiElement
--- @param display_data table<string, ExpGui_Vlayer.elements.stat_bar.display_data>
function Elements.stats_table.refresh(stats_table, display_data)
    for name, stat_bar in pairs(Elements.stats_table.data[stats_table]) do
        Elements.stat_bar.refresh(stat_bar, display_data[name])
    end
end

--- Refresh the tables of every online player
function Elements.stats_table.refresh_online()
    local display_data = Elements.stats_table.calculate_display_data()
    for _, stats_table in Elements.stats_table:online_elements() do
        Elements.stats_table.refresh(stats_table, display_data)
    end
end

--- @class ExpGui_Vlayer.elements.type_dropdown.element_data
--- @field controls LuaGuiElement

--- Dropdown which picks the type of interface to build or list
--- @class ExpGui_Vlayer.elements.type_dropdown: ExpElement
--- @field data table<LuaGuiElement, ExpGui_Vlayer.elements.type_dropdown.element_data>
--- @overload fun(parent: LuaGuiElement, controls: LuaGuiElement): LuaGuiElement
Elements.type_dropdown = Gui.define("vlayer/type_dropdown")
    :draw{
        type = "drop-down",
        items = { type_captions.energy, type_captions.circuit, type_captions.storage_input, type_captions.storage_output },
        selected_index = 1,
    }
    :style{
        width = 200,
    }
    :element_data{
        controls = Gui.from_argument(1),
    }
    :on_selection_state_changed(function(def, _, type_dropdown)
        --- @cast def ExpGui_Vlayer.elements.type_dropdown
        Elements.controls.refresh_interfaces(def.data[type_dropdown].controls)
    end) --[[@as any]]

--- Get the selected interface type
--- @param type_dropdown LuaGuiElement
--- @return ExpScenario_Vlayer.InterfaceType
function Elements.type_dropdown.get_selected(type_dropdown)
    return (assert(interface_types[type_dropdown.selected_index]))
end

--- Dropdown listing the interfaces of the selected type by position
--- @class ExpGui_Vlayer.elements.interface_dropdown: ExpElement
--- @overload fun(parent: LuaGuiElement): LuaGuiElement
Elements.interface_dropdown = Gui.define("vlayer/interface_dropdown")
    :draw{
        type = "drop-down",
    }
    :style{
        width = 200,
    } --[[@as any]]

--- Refresh the listed interfaces
--- @param interface_dropdown LuaGuiElement
--- @param interfaces LuaEntity[]
function Elements.interface_dropdown.refresh(interface_dropdown, interfaces)
    local items = {}
    for index, interface in ipairs(interfaces) do
        local position = interface.position
        items[index] = format_string("%d X %.1f Y %.1f", index, position.x, position.y)
    end
    interface_dropdown.items = items
end

--- Get the selected interface
--- @param interface_dropdown LuaGuiElement
--- @param interfaces LuaEntity[]
--- @return LuaEntity?
function Elements.interface_dropdown.get_selected(interface_dropdown, interfaces)
    local interface = interfaces[interface_dropdown.selected_index]
    if interface and interface.valid then
        return interface
    end
    return nil
end

--- @class ExpGui_Vlayer.elements.control_button.element_data
--- @field controls LuaGuiElement

--- Button which refreshes the listed interfaces
--- @class ExpGui_Vlayer.elements.refresh_button: ExpElement
--- @field data table<LuaGuiElement, ExpGui_Vlayer.elements.control_button.element_data>
--- @overload fun(parent: LuaGuiElement, controls: LuaGuiElement): LuaGuiElement
Elements.refresh_button = Gui.define("vlayer/refresh_button")
    :draw{
        type = "button",
        caption = { "exp-gui_vlayer.caption-refresh" },
    }
    :style{
        width = 200,
    }
    :element_data{
        controls = Gui.from_argument(1),
    }
    :on_click(function(def, _, refresh_button)
        --- @cast def ExpGui_Vlayer.elements.refresh_button
        Elements.controls.refresh_interfaces(def.data[refresh_button].controls)
    end) --[[@as any]]

--- Button which opens the map at the selected interface
--- @class ExpGui_Vlayer.elements.view_button: ExpElement
--- @field data table<LuaGuiElement, ExpGui_Vlayer.elements.control_button.element_data>
--- @overload fun(parent: LuaGuiElement, controls: LuaGuiElement): LuaGuiElement
Elements.view_button = Gui.define("vlayer/view_button")
    :draw{
        type = "button",
        caption = { "exp-gui_vlayer.caption-view" },
    }
    :style{
        width = 200,
    }
    :element_data{
        controls = Gui.from_argument(1),
    }
    :on_click(function(def, player, view_button)
        --- @cast def ExpGui_Vlayer.elements.view_button
        local controls = def.data[view_button].controls
        local interface_type, interface = Elements.controls.get_selected_interface(controls)
        if not interface then return end
        player.set_controller{ type = defines.controllers.remote, position = interface.position, surface = interface.surface }
        player.print{ "exp-gui_vlayer.message-located", type_captions[interface_type], gps_string(interface.position, interface.surface) }
    end) --[[@as any]]

--- Button which toggles selecting an area to build an interface in
--- @class ExpGui_Vlayer.elements.build_button: ExpElement
--- @overload fun(parent: LuaGuiElement): LuaGuiElement
Elements.build_button = Gui.define("vlayer/build_button")
    :track_all_elements()
    :draw{
        type = "button",
        caption = { "exp-gui_vlayer.caption-build" },
    }
    :style{
        width = 200,
    }
    :on_click(function(_, player)
        if SelectArea:stop(player) then
            player.print{ "exp_util.selection_exit", { "exp-gui_vlayer.selection-name" } }
        else
            SelectArea:start(player)
            player.print{ "exp_util.selection_enter", { "exp-gui_vlayer.selection-name" } }
        end
    end) --[[@as any]]

--- Button which removes the selected interface
--- @class ExpGui_Vlayer.elements.remove_button: ExpElement
--- @field data table<LuaGuiElement, ExpGui_Vlayer.elements.control_button.element_data>
--- @overload fun(parent: LuaGuiElement, controls: LuaGuiElement): LuaGuiElement
Elements.remove_button = Gui.define("vlayer/remove_button")
    :track_all_elements()
    :draw{
        type = "button",
        caption = { "exp-gui_vlayer.caption-remove" },
    }
    :style{
        width = 200,
    }
    :element_data{
        controls = Gui.from_argument(1),
    }
    :on_click(function(def, player, remove_button)
        --- @cast def ExpGui_Vlayer.elements.remove_button
        local controls = def.data[remove_button].controls
        local _, interface = Elements.controls.get_selected_interface(controls)
        if not interface then return end
        local position, surface = interface.position, interface.surface
        local interface_type = Vlayer.remove_interface(interface)
        game.print{ "exp-gui_vlayer.message-removed", player.name, type_captions[interface_type], gps_string(position, surface) }
        Elements.controls.refresh_interfaces_online()
    end) --[[@as any]]

--- @class ExpGui_Vlayer.elements.controls.element_data
--- @field type_dropdown LuaGuiElement
--- @field interface_dropdown LuaGuiElement

--- Table of the dropdowns and buttons used to manage interfaces
--- @class ExpGui_Vlayer.elements.controls: ExpElement
--- @field data table<LuaGuiElement, ExpGui_Vlayer.elements.controls.element_data>
--- @overload fun(parent: LuaGuiElement): LuaGuiElement
Elements.controls = Gui.define("vlayer/controls")
    :track_all_elements()
    :draw(function(def, parent)
        --- @cast def ExpGui_Vlayer.elements.controls
        local controls = Gui.elements.scroll_table(parent, 400, 2, "controls")
        local player = Gui.get_player(parent)
        local can_edit = Roles.player_has_permission(player, "exp_scenario.gui.vlayer_edit")

        local type_dropdown = Elements.type_dropdown(controls, controls)
        local interface_dropdown = Elements.interface_dropdown(controls)
        Elements.refresh_button(controls, controls)
        Elements.view_button(controls, controls)
        Elements.build_button(controls).visible = can_edit
        Elements.remove_button(controls, controls).visible = can_edit

        def.data[controls] = {
            type_dropdown = type_dropdown,
            interface_dropdown = interface_dropdown,
        }
        Elements.controls.refresh_interfaces(controls)
        return controls
    end) --[[@as any]]

--- Get the selected interface type
--- @param controls LuaGuiElement
--- @return ExpScenario_Vlayer.InterfaceType
function Elements.controls.get_selected_type(controls)
    return Elements.type_dropdown.get_selected(Elements.controls.data[controls].type_dropdown)
end

--- Get the selected interface and its type
--- @param controls LuaGuiElement
--- @return ExpScenario_Vlayer.InterfaceType, LuaEntity?
function Elements.controls.get_selected_interface(controls)
    local elements = Elements.controls.data[controls]
    local interface_type = Elements.type_dropdown.get_selected(elements.type_dropdown)
    local interfaces = Vlayer.get_interfaces()[interface_type]
    return interface_type, Elements.interface_dropdown.get_selected(elements.interface_dropdown, interfaces)
end

--- Refresh the listed interfaces to match the selected type
--- @param controls LuaGuiElement
function Elements.controls.refresh_interfaces(controls)
    local elements = Elements.controls.data[controls]
    local interface_type = Elements.type_dropdown.get_selected(elements.type_dropdown)
    Elements.interface_dropdown.refresh(elements.interface_dropdown, Vlayer.get_interfaces()[interface_type])
end

--- Refresh the listed interfaces of every online player, used when an interface is built or removed
function Elements.controls.refresh_interfaces_online()
    for _, controls in Elements.controls:online_elements() do
        Elements.controls.refresh_interfaces(controls)
    end
end

--- Refresh whether a player can see the edit buttons
--- @param player LuaPlayer
function Elements.controls.refresh_permissions(player)
    local can_edit = Roles.player_has_permission(player, "exp_scenario.gui.vlayer_edit")
    for _, build_button in Elements.build_button:tracked_elements(player) do
        build_button.visible = can_edit
    end
    for _, remove_button in Elements.remove_button:tracked_elements(player) do
        remove_button.visible = can_edit
    end
end

--- Container added to the left gui flow
--- @class ExpGui_Vlayer.elements.container: ExpElement
--- @overload fun(parent: LuaGuiElement): LuaGuiElement
Elements.container = Gui.define("vlayer/container")
    :draw(function(_, parent)
        local container = Gui.elements.container(parent, 400)
        local stats_table = Elements.stats_table(container)
        Elements.stats_table.refresh(stats_table, Elements.stats_table.calculate_display_data())
        Elements.controls(container)
        return Gui.elements.container.get_root_element(container)
    end) --[[@as any]]

--- Add the element to the left flow with a toolbar button
Gui.add_left_element(Elements.container, false)
Gui.toolbar.create_button{
    name = "toggle_vlayer",
    left_element = Elements.container,
    sprite = "entity/solar-panel",
    tooltip = { "exp-gui_vlayer.tooltip-main" },
    visible = function(player, element)
        return Roles.player_has_permission(player, "exp_scenario.gui.vlayer")
    end
}

--- Replace the one marker entity in a selected area with an interface of the type the player picked
--- @param event EventData.on_player_selected_area
local function on_area_selected(event)
    local player = Gui.get_player(event)
    local surface = event.surface
    local area = expand_area(event.area)
    local force = player.force --[[@as LuaForce]]

    local interface_type = "energy" --- @type ExpScenario_Vlayer.InterfaceType
    for _, controls in Elements.controls:tracked_elements(player) do
        interface_type = Elements.controls.get_selected_type(controls)
    end

    -- Platforms have no chests, so a combinator marks the spot once the research allows it
    local marker_name = "steel-chest"
    if config.power_on_space and surface.platform and interface_type == "energy" then
        local research = config.power_on_space_research
        if force.technologies[research.name].level < research.level then
            player.print({ "exp-gui_vlayer.message-research", research.name, research.level }, Colors.orange_red)
            return
        end
        marker_name = "constant-combinator"
    end

    local markers = surface.find_entities_filtered{ area = area, name = marker_name, force = force }
    if #markers == 0 then
        player.print({ "exp-gui_vlayer.message-no-chest" }, Colors.orange_red)
        return
    elseif #markers > 1 then
        player.print({ "exp-gui_vlayer.message-multiple", type_captions[interface_type] }, Colors.orange_red)
        return
    end

    local marker = assert(markers[1])
    if marker.name == "steel-chest" and not assert(marker.get_inventory(defines.inventory.chest)).is_empty() then
        player.print({ "exp-gui_vlayer.message-chest-not-empty" }, Colors.orange_red)
        return
    end

    if #Vlayer.get_interfaces()[interface_type] >= config.interface_limit[interface_type] then
        player.print({ "exp-gui_vlayer.message-limit", type_captions[interface_type] }, Colors.orange_red)
        return
    end

    local position = marker.position
    marker.destroy()

    if interface_type == "energy" then
        if not Vlayer.create_energy_interface(surface, position, player) then
            player.print({ "exp-gui_vlayer.message-no-space" }, Colors.orange_red)
            return
        end
    elseif interface_type == "circuit" then
        Vlayer.create_circuit_interface(surface, position, player)
    elseif interface_type == "storage_input" then
        Vlayer.create_input_interface(surface, position, player)
    else
        Vlayer.create_output_interface(surface, position, player)
    end

    game.print{ "exp-gui_vlayer.message-built", player.name, type_captions[interface_type], gps_string(position, surface) }
    Elements.controls.refresh_interfaces_online()
end

SelectArea:on_selection(on_area_selected)

--- Refresh the edit buttons as the permissions of a player may have changed
--- @param event EventData.ExpRoles.on_player_roles_changed
local function refresh_player_permissions(event)
    Elements.controls.refresh_permissions(Gui.get_player(event))
end

return {
    elements = Elements,
    events = {
        [Roles.events.on_player_roles_changed] = refresh_player_permissions,
    },
    on_nth_tick = {
        [config.update_tick_gui] = Elements.stats_table.refresh_online,
    }
}
