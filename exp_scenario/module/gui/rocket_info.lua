--[[-- Gui - Rocket Info
Adds a rocket information gui which shows general stats, milestones and build progress of rockets.
The auto launch and remote launch controls were removed because the api no longer exposes auto launch in space age.
]]

local ExpUtil = require("modules/exp_util")
local Storage = require("modules/exp_util/storage")
local Gui = require("modules/exp_gui")
local Roles = require("modules/exp_legacy/expcore/roles")
local config = require("modules/exp_legacy/config/gui/rockets")

--- @class ExpGui_RocketInfo.elements
local Elements = {}

local time_formats = {
    caption = ExpUtil.format_time_factory_locale{ format = "short", minutes = true, seconds = true },
    caption_hours = ExpUtil.format_time_factory_locale{ format = "short", hours = true, minutes = true },
    tooltip = ExpUtil.format_time_factory_locale{ format = "long", minutes = true, seconds = true },
    tooltip_hours = ExpUtil.format_time_factory_locale{ format = "long", hours = true, minutes = true, seconds = true },
}

--- The font colours used for the build progress label
local font_color = {
    neutral = { r = 1, g = 1, b = 1 },
    waiting = { r = 0.3, g = 1, b = 1 },
    launched = { r = 0.3, g = 1, b = 0.3 },
}

--[[
Below here is the rocket data tracking, it stores per force stats and the times each rocket was launched.
This used to live in modules/control/rockets but it is only used by this gui so it has been folded in.
]]

--- @class ExpGui_RocketInfo.silo_data
--- @field entity LuaEntity The rocket silo entity
--- @field force string The name of the force that owns the silo
--- @field launched number The number of rockets launched from this silo
--- @field awaiting_reset boolean True when a launch is ordered but the silo has not reset yet

--- @type table<string, table<number, number>> Force name to an array of launch ticks indexed by rocket number
local rocket_times = {}
--- @type table<string, { first_launch: number?, last_launch: number?, fastest_launch: number? }> Force name to launch stats
local rocket_stats = {}
--- @type table<number, ExpGui_RocketInfo.silo_data> Silo unit number to its data
local rocket_silos = {}

Storage.register({
    rocket_times = rocket_times,
    rocket_stats = rocket_stats,
    rocket_silos = rocket_silos,
}, function(tbl)
    rocket_times = tbl.rocket_times
    rocket_stats = tbl.rocket_stats
    rocket_silos = tbl.rocket_silos
end)

-- The largest rolling average is used to know when an old launch time can be discarded
local largest_rolling_avg = 0
for _, avg_over in pairs(config.stats.rolling_avg) do
    if avg_over > largest_rolling_avg then
        largest_rolling_avg = avg_over
    end
end

--- Get all the valid rocket silos that belong to a force, pruning any that are no longer valid
--- @param force_name string Name of the force to get the silos for
--- @return ExpGui_RocketInfo.silo_data[]
local function get_silos(force_name)
    local rtn = {}
    for unit_number, silo_data in pairs(rocket_silos) do
        if not silo_data.entity.valid then
            rocket_silos[unit_number] = nil
        elseif silo_data.force == force_name then
            rtn[#rtn + 1] = silo_data
        end
    end

    return rtn
end

--- Get the number of rockets that a force has launched
--- @param force_name string Name of the force to get the count for
--- @return number
local function get_rocket_count(force_name)
    return game.forces[force_name].rockets_launched
end

--- Get the total number of rockets launched by all forces
--- @return number
local function get_game_rocket_count()
    local rtn = 0
    for _, force in pairs(game.forces) do
        rtn = rtn + force.rockets_launched
    end

    return rtn
end

--- Get the rolling average time to launch a rocket based on the last count rockets
--- @param force_name string Name of the force to get the average for
--- @param count number Number of rockets to average over
--- @return number # Number of ticks required to launch one rocket
local function get_rolling_average(force_name, count)
    local times = rocket_times[force_name]
    local rocket_count = game.forces[force_name].rockets_launched
    if rocket_count == 0 or not times then return 0 end

    local last_launch_time = times[rocket_count] or 0
    local start_rocket_time = 0
    if count < rocket_count then
        start_rocket_time = times[rocket_count - count + 1] or 0
        rocket_count = count
    end

    return math.floor((last_launch_time - start_rocket_time) / rocket_count)
end

--[[
Below here is the gui, it is split into three collapsible sections; stats, milestones, and build progress.
]]

--- Toggle the visible state of a section, the section is stored in the element data
--- @class ExpGui_RocketInfo.elements.toggle_section_button: ExpElement
--- @field data table<LuaGuiElement, LuaGuiElement>
--- @overload fun(parent: LuaGuiElement, section: LuaGuiElement): LuaGuiElement
Elements.toggle_section_button = Gui.define("rocket_info/toggle_section_button")
    :draw{
        type = "sprite-button",
        sprite = "utility/expand",
        tooltip = { "exp-gui_rocket-info.tooltip-toggle-section-expand" },
        style = "frame_action_button",
    }
    :style{
        size = 20,
        padding = -2,
    }
    :element_data(
        Gui.from_argument(1)
    )
    :on_click(function(def, player, element)
        --- @cast def ExpGui_RocketInfo.elements.toggle_section_button
        local section = def.data[element]
        if Gui.toggle_visible_state(section) then
            element.sprite = "utility/collapse"
            element.tooltip = { "exp-gui_rocket-info.tooltip-toggle-section-collapse" }
        else
            element.sprite = "utility/expand"
            element.tooltip = { "exp-gui_rocket-info.tooltip-toggle-section-expand" }
        end
    end) --[[ @as any ]]

--- A clickable coordinate label which opens the silo location on the map when pressed
--- @class ExpGui_RocketInfo.elements.position_label: ExpElement
--- @field data table<LuaGuiElement, number>
--- @overload fun(parent: LuaGuiElement, opts: { caption: LocalisedString, tooltip: LocalisedString?, unit_number: number }): LuaGuiElement
Elements.position_label = Gui.define("rocket_info/position_label")
    :draw{
        type = "label",
        caption = Gui.from_argument("caption"),
        tooltip = Gui.from_argument("tooltip"),
    }
    :style{
        padding = { 0, 2 },
    }
    :element_data(
        Gui.from_argument("unit_number")
    )
    :on_click(function(def, player, element)
        --- @cast def ExpGui_RocketInfo.elements.position_label
        if not config.progress.allow_zoom_to_map then return end
        local silo_data = rocket_silos[def.data[element]]
        if not silo_data or not silo_data.entity.valid then return end
        local entity = silo_data.entity
        player.set_controller{ type = defines.controllers.remote, position = entity.position, surface = entity.surface }
    end) --[[ @as any ]]

--- Add a name and value label pair to a data table
--- @param data_table LuaGuiElement The two column table to add the pair to
--- @param name string The data name, used to select the locale key
--- @param subname number? Optional subname passed as a parameter to the locale string
--- @param value LocalisedString The value to display
--- @param value_tooltip LocalisedString? Optional tooltip for the value label
local function add_data_label(data_table, name, subname, value, value_tooltip)
    local name_label = data_table.add{
        type = "label",
        caption = { "exp-gui_rocket-info.data-caption-" .. name, subname },
        tooltip = { "exp-gui_rocket-info.data-tooltip-" .. name, subname },
    }
    name_label.style.padding = { 0, 2 }

    local value_label = data_table.add{
        type = "label",
        caption = value,
        tooltip = value_tooltip,
    }
    value_label.style.padding = { 0, 2 }
end

--- Data table showing the launch statistics for a force
--- @class ExpGui_RocketInfo.elements.stats_table: ExpElement
--- @overload fun(parent: LuaGuiElement): LuaGuiElement
Elements.stats_table = Gui.define("rocket_info/stats_table")
    :track_all_elements()
    :draw(function(def, parent)
        return Gui.elements.scroll_table(parent, 215, 2)
    end) --[[ @as any ]]

--- Refresh a stats table with the most recent data for a force
--- @param stats_table LuaGuiElement
--- @param force_name string
function Elements.stats_table.refresh(stats_table, force_name)
    stats_table.clear()
    local stats = rocket_stats[force_name] or {}
    local force_rockets = get_rocket_count(force_name)

    if config.stats.show_first_rocket then
        local value = stats.first_launch or 0
        add_data_label(stats_table, "first-launch", nil, time_formats.caption_hours(value), time_formats.tooltip_hours(value))
    end

    if config.stats.show_last_rocket then
        local value = stats.last_launch or 0
        add_data_label(stats_table, "last-launch", nil, time_formats.caption_hours(value), time_formats.tooltip_hours(value))
    end

    if config.stats.show_fastest_rocket then
        local value = stats.fastest_launch or 0
        add_data_label(stats_table, "fastest-launch", nil, time_formats.caption_hours(value), time_formats.tooltip_hours(value))
    end

    if config.stats.show_total_rockets then
        local total_rockets = get_game_rocket_count()
        if total_rockets == 0 then total_rockets = 1 end
        local percentage = math.floor(force_rockets / total_rockets * 1000) / 10
        add_data_label(stats_table, "total-rockets", nil, tostring(force_rockets), { "exp-gui_rocket-info.value-tooltip-total-rockets", percentage })
    end

    if config.stats.show_game_avg then
        local avg = force_rockets > 0 and math.floor(game.tick / force_rockets) or 0
        add_data_label(stats_table, "avg-launch", nil, time_formats.caption(avg), time_formats.tooltip(avg))
    end

    for _, avg_over in pairs(config.stats.rolling_avg) do
        local avg = get_rolling_average(force_name, avg_over)
        add_data_label(stats_table, "avg-launch-n", avg_over, time_formats.caption(avg), time_formats.tooltip(avg))
    end
end

--- Data table showing the milestones for a force
--- @class ExpGui_RocketInfo.elements.milestones_table: ExpElement
--- @overload fun(parent: LuaGuiElement): LuaGuiElement
Elements.milestones_table = Gui.define("rocket_info/milestones_table")
    :track_all_elements()
    :draw(function(def, parent)
        return Gui.elements.scroll_table(parent, 215, 2)
    end) --[[ @as any ]]

--- Refresh a milestones table with the most recent data for a force
--- @param milestones_table LuaGuiElement
--- @param force_name string
function Elements.milestones_table.refresh(milestones_table, force_name)
    milestones_table.clear()
    local force_rockets = get_rocket_count(force_name)
    local times = rocket_times[force_name] or {}

    for _, milestone in ipairs(config.milestones) do
        if milestone <= force_rockets then
            local time = times[milestone] or 0
            add_data_label(milestones_table, "milestone-n", milestone, time_formats.caption_hours(time), time_formats.tooltip_hours(time))
        else
            -- The first unachieved milestone is shown as the next milestone then we stop
            add_data_label(milestones_table, "milestone-n", milestone, { "exp-gui_rocket-info.data-caption-milestone-next" }, { "exp-gui_rocket-info.data-tooltip-milestone-next" })
            break
        end
    end
end

--- Data table showing the build progress of each silo for a force
--- @class ExpGui_RocketInfo.elements.progress_table: ExpElement
--- @overload fun(parent: LuaGuiElement): LuaGuiElement
Elements.progress_table = Gui.define("rocket_info/progress_table")
    :track_all_elements()
    :draw(function(def, parent)
        return Gui.elements.scroll_table(parent, 215, 3)
    end) --[[ @as any ]]

--- Refresh a progress table with the most recent data for a force
--- @param progress_table LuaGuiElement
--- @param force_name string
function Elements.progress_table.refresh(progress_table, force_name)
    progress_table.clear()
    local silos = get_silos(force_name)

    if #silos == 0 then
        progress_table.add{
            type = "label",
            caption = { "exp-gui_rocket-info.progress-no-silos" },
        }.style.padding = { 1, 2 }
        return
    end

    local zoom_tooltip = config.progress.allow_zoom_to_map and { "exp-gui_rocket-info.progress-label-tooltip" } or nil
    for _, silo_data in pairs(silos) do
        local entity = silo_data.entity
        local position = entity.position

        -- Work out the progress caption, tooltip and colour
        local waiting = entity.status == defines.entity_status.waiting_to_launch_rocket
        local progress_caption = { "exp-gui_rocket-info.progress-caption", entity.rocket_parts }
        local progress_tooltip = { "exp-gui_rocket-info.progress-tooltip", silo_data.launched }
        local progress_color = font_color.neutral
        if waiting and silo_data.awaiting_reset then
            progress_caption = { "exp-gui_rocket-info.progress-launched" }
            progress_color = font_color.launched
        elseif waiting then
            progress_caption = { "exp-gui_rocket-info.progress-caption", 100 }
            progress_color = font_color.waiting
        else
            silo_data.awaiting_reset = false
        end

        -- Add the clickable coordinates and the progress label
        Elements.position_label(progress_table, { caption = { "exp-gui_rocket-info.progress-x-pos", position.x }, tooltip = zoom_tooltip, unit_number = entity.unit_number })
        Elements.position_label(progress_table, { caption = { "exp-gui_rocket-info.progress-y-pos", position.y }, tooltip = zoom_tooltip, unit_number = entity.unit_number })
        local progress_label = progress_table.add{
            type = "label",
            caption = progress_caption,
            tooltip = progress_tooltip,
        }
        progress_label.style.padding = { 0, 2 }
        progress_label.style.font_color = progress_color
    end
end

--- Add a collapsible section to a container, returns the populated data table
--- @param container LuaGuiElement The container frame to add the section to
--- @param section_name string Used to select the locale keys for the header
--- @param table_define ExpElement The data table element define to add
--- @param force_name string The force to populate the table with
--- @return LuaGuiElement
local function add_section(container, section_name, table_define, force_name)
    local header = Gui.elements.header(container, {
        caption = { "exp-gui_rocket-info.section-caption-" .. section_name },
        tooltip = { "exp-gui_rocket-info.section-tooltip-" .. section_name },
    })

    local data_table = table_define(container)
    table_define.refresh(data_table, force_name)

    -- The scroll pane is the parent of the table, it is what gets collapsed
    local scroll_pane = assert(data_table.parent)
    scroll_pane.visible = false
    Elements.toggle_section_button(header, scroll_pane)

    return data_table
end

--- Container added to the left gui flow
--- @class ExpGui_RocketInfo.elements.container: ExpElement
--- @overload fun(parent: LuaGuiElement): LuaGuiElement
Elements.container = Gui.define("rocket_info/container")
    :draw(function(def, parent)
        local container = Gui.elements.container(parent, 200)
        container.style.padding = 0

        local force_name = Gui.get_player(parent).force.name --[[ @as string ]]

        if config.stats.show_stats then
            add_section(container, "stats", Elements.stats_table, force_name)
        end

        if config.milestones.show_milestones then
            add_section(container, "milestones", Elements.milestones_table, force_name)
        end

        if config.progress.show_progress then
            add_section(container, "progress", Elements.progress_table, force_name)
        end

        return Gui.elements.container.get_root_element(container)
    end) --[[ @as any ]]

--- Add the element to the left flow with a toolbar button
Gui.add_left_element(Elements.container, false)
Gui.toolbar.create_button{
    name = "toggle_rocket_info",
    left_element = Elements.container,
    sprite = "item/rocket-silo",
    tooltip = { "exp-gui_rocket-info.tooltip-main" },
    visible = function(player, element)
        return Roles.player_allowed(player, "gui/rocket-info")
    end
}

--[[
Below here is the event handling, the data tracking and gui refreshing are wired up to the same events.
]]

--- Refresh the stats and milestones tables for all online players on a force
--- @param force_name string
local function refresh_force_stats(force_name)
    local force = game.forces[force_name]
    for _, stats_table in Elements.stats_table:online_elements(force) do
        Elements.stats_table.refresh(stats_table, force_name)
    end
    for _, milestones_table in Elements.milestones_table:online_elements(force) do
        Elements.milestones_table.refresh(milestones_table, force_name)
    end
end

--- Refresh the progress table for all online players on a force
--- @param force_name string
local function refresh_force_progress(force_name)
    local force = game.forces[force_name]
    for _, progress_table in Elements.progress_table:online_elements(force) do
        Elements.progress_table.refresh(progress_table, force_name)
    end
end

--- Record the launch and update the stats when a cargo pod finishes ascending
--- @param event EventData.on_cargo_pod_finished_ascending
local function on_cargo_pod_finished_ascending(event)
    local force = event.cargo_pod.force --[[ @as LuaForce ]]
    local force_name = force.name
    local rockets_launched = force.rockets_launched

    -- Update the launch stats for the force
    local stats = rocket_stats[force_name]
    if not stats then
        stats = {}
        rocket_stats[force_name] = stats
    end

    if rockets_launched == 1 then
        stats.first_launch = event.tick
        stats.fastest_launch = event.tick
    elseif stats.last_launch and event.tick - stats.last_launch < (stats.fastest_launch or math.huge) then
        stats.fastest_launch = event.tick - stats.last_launch
    end

    stats.last_launch = event.tick

    -- Append the launch tick into the times array
    local times = rocket_times[force_name]
    if not times then
        times = {}
        rocket_times[force_name] = times
    end

    times[rockets_launched] = event.tick

    -- Discard the launch time that is no longer needed by any rolling average unless it is a milestone
    local remove_rocket = rockets_launched - largest_rolling_avg
    if remove_rocket > 0 and not table.array_contains(config.milestones, remove_rocket) then
        times[remove_rocket] = nil
    end

    refresh_force_stats(force_name)
    refresh_force_progress(force_name)
end

--- Mark a silo as awaiting reset when a launch is ordered
--- @param event EventData.on_rocket_launch_ordered
local function on_rocket_launch_ordered(event)
    local silo_data = rocket_silos[event.rocket_silo.unit_number]
    if not silo_data then return end
    silo_data.launched = silo_data.launched + 1
    silo_data.awaiting_reset = true
    refresh_force_progress(event.rocket_silo.force.name)
end

--- Add a silo to the list when it is built
--- @param event EventData.on_built_entity | EventData.on_robot_built_entity | EventData.script_raised_built | EventData.script_raised_revive
local function on_built(event)
    local entity = event.entity
    if not entity.valid or entity.name ~= "rocket-silo" then return end
    rocket_silos[entity.unit_number] = {
        entity = entity,
        force = entity.force.name,
        launched = 0,
        awaiting_reset = false,
    }
    refresh_force_progress(entity.force.name)
end

--- Refresh the progress for all forces that own at least one silo
local function refresh_all_progress()
    for _, force in pairs(game.forces) do
        if #get_silos(force.name) > 0 then
            refresh_force_progress(force.name)
        end
    end
end

local e = defines.events

return {
    elements = Elements,
    events = {
        [e.on_cargo_pod_finished_ascending] = on_cargo_pod_finished_ascending,
        [e.on_rocket_launch_ordered] = on_rocket_launch_ordered,
        [e.on_built_entity] = on_built,
        [e.on_robot_built_entity] = on_built,
        [e.script_raised_built] = on_built,
        [e.script_raised_revive] = on_built,
    },
    on_nth_tick = {
        [150] = refresh_all_progress,
    }
}
