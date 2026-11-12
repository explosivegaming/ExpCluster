--[[-- Gui - Virtual Layer
Shows what the virtual layer holds and lets players build and remove its interfaces
]]

local Gui = require("modules/exp_gui")
local Roles = require("modules/exp_roles")
local Colors = require("modules/exp_util/include/color")
local Vlayer = require("modules/exp_scenario/control/vlayer")
local Feature = require("modules/exp_scenario/features")
local feature, config = Vlayer.feature, Vlayer.config
local format_number = require("util").format_number

local Selection = require("modules/exp_util/selection")
local SelectArea = Selection.connect("ExpGui_Vlayer")

local floor = math.floor
local ceil = math.ceil
local max = math.max
local min = math.min
local format_string = string.format

local gui_width = {
    main = 500,
    left = 200,
    right = 300,
    half = 250
}

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
for _, name in ipairs{ "production", "sustained", "capacity", "surface-area", "solar-panel", "accumulator" } do
    stats[#stats + 1] = {
        name = name,
        caption = (name == "solar-panel" or name == "accumulator")
            and { "", "[img=entity/" .. name .. "] ", prototypes.entity[name].localised_name }
            or { "exp-gui_vlayer.caption-stat-" .. name },
        tooltip = (name == "solar-panel" or name == "accumulator")
            and { "", prototypes.entity[name].localised_description}
            or { "exp-gui_vlayer.tooltip-stat-" .. name },
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
        width = gui_width.left,
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
        width = gui_width.right,
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
        local stats_table = Gui.elements.scroll_table(parent, gui_width.main, 2, "stats")
        local stat_bars = {}
        for _, stat in ipairs(stats) do
            Elements.stat_label(stats_table, stat.caption, stat.tooltip)
            stat_bars[stat.name] = Elements.stat_bar(stats_table)
        end
        def.data[stats_table] = stat_bars
        return stats_table
    end) --[[@as any]]

--- Calculate the display data of every statistic, the same for every player
--- @param s_index number Surface index
--- @return table<string, ExpGui_Vlayer.elements.stat_bar.display_data>
function Elements.stats_table.calculate_display_data(s_index)
    local statistics = Vlayer.get_statistics(s_index)
    local items = Vlayer.get_items(s_index)
    local allocated = Vlayer.get_allocated_items(s_index)
    local energy_production = ceil(statistics.energy_production)
    local energy_max = ceil(statistics.energy_max)
    local energy_sustained = ceil(statistics.energy_sustained)
    local limit_production = min(statistics.energy_input_limit, energy_production)
    local production = limit_production / max(energy_max, 1)
    local limit_sustained = min(statistics.energy_output_limit, energy_sustained)
    local sustained = limit_sustained / max(statistics.energy_total_production, 1)
    local capacity = statistics.energy_storage / max(statistics.energy_capacity, 1)
    local surface_area = statistics.remaining_surface_area / max(statistics.total_surface_area, 1)
    local allocated_solar = allocated["solar-panel"] and allocated["solar-panel"][0] or 0
    local items_solar = items["solar-panel"] and items["solar-panel"][0] or 0
    local allocated_accu = allocated["accumulator"] and allocated["accumulator"][0] or 0
    local items_accu = items["accumulator"] and items["accumulator"][0] or 0
    local solar = allocated_solar / max(items_solar, 1)
    local accu = allocated_accu / max(items_accu, 1)
    return {
        production = {
            value = production,
            caption = format_string(
                "%s / %s, %.1f %%",
                statistics.energy_input_limit < energy_production
                and format_string(
                    "%s (%s)",
                    format_energy(energy_production, "W"),
                    format_energy(limit_production, "W")
                )
                or format_energy(energy_production, "W"),
                format_energy(energy_max, "W"),
                production * 100
            ),
        },
        sustained = {
            value = sustained,
            caption = format_string(
                "%s / %s, %.1f %%",
                statistics.energy_input_limit < energy_sustained
                and format_string(
                    "%s (%s)",
                    format_energy(energy_sustained, "W"),
                    format_energy(limit_sustained, "W")
                )
                or format_energy(energy_sustained, "W"),
                format_energy(energy_max, "W"),
                sustained * 100
            ),
        },
        capacity = {
            value = capacity,
            caption = format_string(
                "%s / %s, %.1f %%",
                format_energy(statistics.energy_storage, "J"),
                format_energy(statistics.energy_capacity, "J"),
                capacity * 100
            ),
        },
        ["surface-area"] = {
            value = min(max(surface_area / 0.1, 0), 1),
            caption = format_string(
                "%s, %.1f %%",
                format_number(statistics.remaining_surface_area, false),
                surface_area * 100
            ),
        },
        ["solar-panel"] = {
            value = solar,
            caption = format_string(
                "%s / %s, %.1f %%",
                format_number(allocated_solar, false),
                format_number(items_solar, false),
                solar * 100
            ),
        },
        ["accumulator"] = {
            value = accu,
            caption = format_string(
                "%s / %s, %.1f %%",
                format_number(allocated_accu, false),
                format_number(items_accu, false),
                accu * 100
            ),
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
    for _, controls in Elements.controls:online_elements() do
        local elements = Elements.controls.data[controls]
        local element = elements.surface_dropdown
        local surface = 1
        if element then
            local surface_name = element.items[element.selected_index]
            if surface_name then
                ---@diagnostic disable-next-line: undefined-field
                surface = game.surfaces[surface_name].index
            end
        end
        local display_data = Elements.stats_table.calculate_display_data(surface)
        for _, stats_table in Elements.stats_table:online_elements() do
            Elements.stats_table.refresh(stats_table, display_data)
        end
    end
end

--- Dropdown listing the surfaces available in vlayer
--- @class ExpGui_Vlayer.elements.surface_dropdown: ExpElement
--- @overload fun(parent: LuaGuiElement, controls: LuaGuiElement): LuaGuiElement
Elements.surface_dropdown = Gui.define("vlayer/surface_dropdown")
    :draw{
        type = "drop-down",
    }
    :style{
        width = gui_width.half,
    }
    :element_data{
        controls = Gui.from_argument(1),
    }
    :on_selection_state_changed(function(def, _, surface_dropdown)
        --- @cast def ExpGui_Vlayer.elements.type_dropdown
        Elements.controls.refresh_interfaces(def.data[surface_dropdown].controls)
    end) --[[@as any]]

--- Refresh the listed interfaces
--- @param surface_dropdown LuaGuiElement
--- @param surfaces LuaSurface[]
function Elements.surface_dropdown.refresh(surface_dropdown, surfaces)
    local items = {}
    local index = 1
    for _, surface in pairs(surfaces) do
        items[index] = surface.name
        index = index + 1
    end
    surface_dropdown.items = items
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
        width = gui_width.half,
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
--- @overload fun(parent: LuaGuiElement, controls: LuaGuiElement): LuaGuiElement
Elements.interface_dropdown = Gui.define("vlayer/interface_dropdown")
    :draw{
        type = "drop-down",
    }
    :style{
        width = gui_width.half,
    }
    :element_data{
        controls = Gui.from_argument(1),
    }
    :on_selection_state_changed(function(def, player, interface_dropdown)
        --- @cast def ExpGui_Vlayer.elements.interface_dropdown
        local controls = def.data[interface_dropdown].controls
        local interface_type, interface = Elements.controls.get_selected_interface(controls)
        if not interface then return end
        player.set_controller{ type = defines.controllers.remote, position = interface.position, surface = interface.surface }
        player.print{ "exp-gui_vlayer.message-located", type_captions[interface_type], gps_string(interface.position, interface.surface) }
    end) --[[@as any]]

--- Refresh the listed interfaces
--- @param interface_dropdown LuaGuiElement
--- @param interfaces LuaEntity[]
function Elements.interface_dropdown.refresh(interface_dropdown, interfaces)
    local items = {}
    for index, interface in ipairs(interfaces) do
        local position = interface.position
        items[index] = format_string("[%d] (%.1f, %.1f)", index, position.x, position.y)
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
        width = gui_width.half,
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
        width = gui_width.half,
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
--- @field surface_dropdown LuaGuiElement
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
        local controls = Gui.elements.scroll_table(parent, gui_width.main, 2, "controls")
        local player = Gui.get_player(parent)
        local can_edit = Roles.player_has_permission(player, "exp_scenario.gui.vlayer_edit")

        local surface_dropdown = Elements.surface_dropdown(controls, controls)
        local type_dropdown = Elements.type_dropdown(controls, controls)
        local interface_dropdown = Elements.interface_dropdown(controls, controls)
        Elements.build_button(controls).visible = can_edit
        Elements.remove_button(controls, controls).visible = can_edit

        def.data[controls] = {
            surface_dropdown = surface_dropdown,
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
    local element = elements.surface_dropdown
    local surface = 1
    if element then
        local surface_name = element.items[element.selected_index]
        if surface_name then
            ---@diagnostic disable-next-line: undefined-field
            surface = game.surfaces[surface_name].index
        end
    end
    local interfaces = Vlayer.get_interfaces(surface)[interface_type]
    return interface_type, Elements.interface_dropdown.get_selected(elements.interface_dropdown, interfaces)
end

--- Refresh the listed interfaces to match the selected type
--- @param controls LuaGuiElement
function Elements.controls.refresh_interfaces(controls)
    local elements = Elements.controls.data[controls]
    local interface_type = Elements.type_dropdown.get_selected(elements.type_dropdown)
    local element = elements.surface_dropdown
    local surface = 1
    if element then
        local surface_name = element.items[element.selected_index]
        if surface_name then
            ---@diagnostic disable-next-line: undefined-field
            surface = game.surfaces[surface_name].index
        end
    end
    Elements.interface_dropdown.refresh(elements.interface_dropdown, Vlayer.get_interfaces(surface)[interface_type])
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
        local container = Gui.elements.container(parent, gui_width.main)
        local stats_table = Elements.stats_table(container)
        Elements.controls(container)
        for _, controls in Elements.controls:online_elements() do
            local elements = Elements.controls.data[controls]
            Elements.stats_table.refresh(stats_table, Elements.stats_table.calculate_display_data(1))
        end
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
        return feature:is_enabled() and Roles.player_has_permission(player, "exp_scenario.gui.vlayer")
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

    local markers = surface.find_entities_filtered{ area = area, name = "steel-chest", force = force }
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

    if config.interface_limit[interface_type] >= 0 and #Vlayer.get_interfaces(surface.index)[interface_type] >= config.interface_limit[interface_type] then
        player.print({ "exp-gui_vlayer.message-limit", type_captions[interface_type] }, Colors.orange_red)
        return
    end

    local position = marker.position
    marker.destroy()

    if interface_type == "energy" then
        if not Vlayer.create_energy_interface(surface, position, player) then
            player.print({ "exp-gui_vlayer.message-no-space" }, Colors.orange_red)
            player.insert{ name = "steel-chest", count = 1 }
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

--- Refresh the dropdown list when surface is updated
local function update_surface()
    -- global surface will have its data point to the main surface
    if config.global_surface then return end
    for _, controls in Elements.controls:online_elements() do
        local elements = Elements.controls.data[controls]
        Elements.surface_dropdown.refresh(elements.surface_dropdown, game.surfaces)
    end
end

local e = defines.events

return feature:guard{
    elements = Elements,
    events = {
        [Roles.events.on_player_roles_changed] = refresh_player_permissions,
        [e.on_surface_created] = update_surface,
        [e.on_surface_renamed] = update_surface,
        [e.on_surface_imported] = update_surface,
        [Feature.events.on_config_updated] = function(event)
            if event.feature_name == feature.name and event.path == "global_surface" then
                update_surface()
            end
        end,
    },
    on_nth_tick = {
        [60] = Elements.stats_table.refresh_online,
    }
}
