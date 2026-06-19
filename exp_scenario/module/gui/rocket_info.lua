--[[-- Gui - Rocket Info
Adds a rocket information gui which shows general stats, milestones and build progress of rockets.
The auto launch and remote launch controls were removed because the api no longer exposes auto launch in space age.
]]

local ExpUtil = require("modules/exp_util")
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

-- The largest rolling average is used to know when an old launch time can be discarded
local largest_rolling_avg = 0
for _, avg_over in pairs(config.stats.rolling_avg) do
    if avg_over > largest_rolling_avg then
        largest_rolling_avg = avg_over
    end
end

--[[
The per force rocket data is stored on the container element data using the force scope, this means it
persists with the rest of the gui data and is cleaned up when forces are merged. It holds the launch
stats, the tick each rocket was launched on, and the silos that belong to the force.
]]

--- @class ExpGui_RocketInfo.silo_data
--- @field entity LuaEntity The rocket silo entity
--- @field launched number The number of rockets launched from this silo
--- @field awaiting_reset boolean True when a launch is ordered but the silo has not reset yet

--- @class ExpGui_RocketInfo.force_data
--- @field stats { first_launch: number?, last_launch: number?, fastest_launch: number? } Launch stats for the force
--- @field times table<number, number> Launch tick indexed by rocket number
--- @field silos table<number, ExpGui_RocketInfo.silo_data> Silo data indexed by unit number

--- Get the rocket data for a force, creating it if it does not exist
--- @param force LuaForce
--- @return ExpGui_RocketInfo.force_data
local function get_force_data(force)
    local data = Elements.container.data[force]
    if not data then
        data = { stats = {}, times = {}, silos = {} }
        Elements.container.data[force] = data
    end
    return data
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
--- @param force LuaForce
--- @param count number Number of rockets to average over
--- @return number # Number of ticks required to launch one rocket
local function get_rolling_average(force, count)
    local rocket_count = force.rockets_launched
    if rocket_count == 0 then return 0 end

    local times = get_force_data(force).times
    local last_launch_time = times[rocket_count] or 0
    local start_rocket_time = 0
    if count < rocket_count then
        start_rocket_time = times[rocket_count - count + 1] or 0
        rocket_count = count
    end

    return math.floor((last_launch_time - start_rocket_time) / rocket_count)
end

--- @class ExpGui_RocketInfo.stat_row
--- @field key string Unique key used to look up the value label
--- @field name string Data name used to select the locale keys
--- @field subname number? Optional subname passed as a locale parameter
--- @field value LocalisedString
--- @field tooltip LocalisedString?

--- Compute the ordered stat rows for a force
--- @param force LuaForce
--- @return ExpGui_RocketInfo.stat_row[]
local function compute_stat_rows(force)
    local stats = get_force_data(force).stats
    local force_rockets = force.rockets_launched
    local rows = {}

    if config.stats.show_first_rocket then
        local value = stats.first_launch or 0
        rows[#rows + 1] = { key = "first-launch", name = "first-launch", value = time_formats.caption_hours(value), tooltip = time_formats.tooltip_hours(value) }
    end

    if config.stats.show_last_rocket then
        local value = stats.last_launch or 0
        rows[#rows + 1] = { key = "last-launch", name = "last-launch", value = time_formats.caption_hours(value), tooltip = time_formats.tooltip_hours(value) }
    end

    if config.stats.show_fastest_rocket then
        local value = stats.fastest_launch or 0
        rows[#rows + 1] = { key = "fastest-launch", name = "fastest-launch", value = time_formats.caption_hours(value), tooltip = time_formats.tooltip_hours(value) }
    end

    if config.stats.show_total_rockets then
        local total_rockets = get_game_rocket_count()
        if total_rockets == 0 then total_rockets = 1 end
        local percentage = math.floor(force_rockets / total_rockets * 1000) / 10
        rows[#rows + 1] = { key = "total-rockets", name = "total-rockets", value = tostring(force_rockets), tooltip = { "exp-gui_rocket-info.value-tooltip-total-rockets", percentage } }
    end

    if config.stats.show_game_avg then
        local avg = force_rockets > 0 and math.floor(game.tick / force_rockets) or 0
        rows[#rows + 1] = { key = "avg-launch", name = "avg-launch", value = time_formats.caption(avg), tooltip = time_formats.tooltip(avg) }
    end

    for _, avg_over in pairs(config.stats.rolling_avg) do
        local avg = get_rolling_average(force, avg_over)
        rows[#rows + 1] = { key = "avg-launch-n-" .. avg_over, name = "avg-launch-n", subname = avg_over, value = time_formats.caption(avg), tooltip = time_formats.tooltip(avg) }
    end

    return rows
end

--- @class ExpGui_RocketInfo.milestone_row
--- @field milestone number The milestone this row represents
--- @field value LocalisedString
--- @field tooltip LocalisedString

--- Compute the ordered milestone rows for a force, up to and including the next unachieved milestone
--- @param force LuaForce
--- @return ExpGui_RocketInfo.milestone_row[]
local function compute_milestone_rows(force)
    local times = get_force_data(force).times
    local force_rockets = force.rockets_launched
    local rows = {}

    for _, milestone in ipairs(config.milestones) do
        -- The milestones config mixes the show_milestones flag with the milestone numbers
        if type(milestone) == "number" then
            if milestone <= force_rockets then
                local time = times[milestone] or 0
                rows[#rows + 1] = { milestone = milestone, value = time_formats.caption_hours(time), tooltip = time_formats.tooltip_hours(time) }
            else
                rows[#rows + 1] = { milestone = milestone, value = { "exp-gui_rocket-info.data-caption-milestone-next" }, tooltip = { "exp-gui_rocket-info.data-tooltip-milestone-next" } }
                break
            end
        end
    end

    return rows
end

--- @class ExpGui_RocketInfo.progress_row
--- @field x LocalisedString
--- @field y LocalisedString
--- @field caption LocalisedString
--- @field tooltip LocalisedString
--- @field color Color

--- Compute the progress row data for a silo, clears awaiting_reset once the silo is no longer waiting
--- @param silo_data ExpGui_RocketInfo.silo_data
--- @return ExpGui_RocketInfo.progress_row
local function compute_progress_row(silo_data)
    local entity = silo_data.entity
    local position = entity.position
    local waiting = entity.status == defines.entity_status.waiting_to_launch_rocket

    local caption = { "exp-gui_rocket-info.progress-caption", entity.rocket_parts }
    local color = font_color.neutral
    if waiting and silo_data.awaiting_reset then
        caption = { "exp-gui_rocket-info.progress-launched" }
        color = font_color.launched
    elseif waiting then
        caption = { "exp-gui_rocket-info.progress-caption", 100 }
        color = font_color.waiting
    else
        silo_data.awaiting_reset = false
    end

    return {
        x = { "exp-gui_rocket-info.progress-x-pos", position.x },
        y = { "exp-gui_rocket-info.progress-y-pos", position.y },
        caption = caption,
        tooltip = { "exp-gui_rocket-info.progress-tooltip", silo_data.launched },
        color = color,
    }
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
--- @field data table<LuaGuiElement, LuaEntity>
--- @overload fun(parent: LuaGuiElement, opts: { caption: LocalisedString, tooltip: LocalisedString?, entity: LuaEntity }): LuaGuiElement
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
        Gui.from_argument("entity")
    )
    :on_click(function(def, player, element)
        --- @cast def ExpGui_RocketInfo.elements.position_label
        if not config.progress.allow_zoom_to_map then return end
        local entity = def.data[element]
        if not entity or not entity.valid then return end
        player.set_controller{ type = defines.controllers.remote, position = entity.position, surface = entity.surface }
    end) --[[ @as any ]]

--- Data table showing the launch statistics for a force
--- @class ExpGui_RocketInfo.elements.stats_table: ExpElement
--- @field data table<LuaGuiElement, table<string, LuaGuiElement>>
--- @overload fun(parent: LuaGuiElement): LuaGuiElement
Elements.stats_table = Gui.define("rocket_info/stats_table")
    :track_all_elements()
    :draw(function(def, parent)
        --- @cast def ExpGui_RocketInfo.elements.stats_table
        local data_table = Gui.elements.scroll_table(parent, 215, 2)
        def.data[data_table] = {}
        return data_table
    end) --[[ @as any ]]

--- Add a stat row to the table and store its value label
--- @param data_table LuaGuiElement
--- @param row ExpGui_RocketInfo.stat_row
function Elements.stats_table.add_row(data_table, row)
    local labels = Elements.stats_table.data[data_table]
    local name_label = data_table.add{
        type = "label",
        caption = { "exp-gui_rocket-info.data-caption-" .. row.name, row.subname },
        tooltip = { "exp-gui_rocket-info.data-tooltip-" .. row.name, row.subname },
    }
    name_label.style.padding = { 0, 2 }

    local value_label = data_table.add{
        type = "label",
        caption = row.value,
        tooltip = row.tooltip,
    }
    value_label.style.padding = { 0, 2 }

    labels[row.key] = value_label
end

--- Refresh the stats table for a force, adding any rows that do not yet exist
--- @param data_table LuaGuiElement
--- @param force LuaForce
function Elements.stats_table.refresh(data_table, force)
    local labels = Elements.stats_table.data[data_table]
    for _, row in ipairs(compute_stat_rows(force)) do
        local value_label = labels[row.key]
        if value_label then
            value_label.caption = row.value
            value_label.tooltip = row.tooltip
        else
            Elements.stats_table.add_row(data_table, row)
        end
    end
end

--- Data table showing the milestones for a force
--- @class ExpGui_RocketInfo.elements.milestones_table: ExpElement
--- @field data table<LuaGuiElement, table<number, LuaGuiElement>>
--- @overload fun(parent: LuaGuiElement): LuaGuiElement
Elements.milestones_table = Gui.define("rocket_info/milestones_table")
    :track_all_elements()
    :draw(function(def, parent)
        --- @cast def ExpGui_RocketInfo.elements.milestones_table
        local data_table = Gui.elements.scroll_table(parent, 215, 2)
        def.data[data_table] = {}
        return data_table
    end) --[[ @as any ]]

--- Add a milestone row to the table and store its value label
--- @param data_table LuaGuiElement
--- @param row ExpGui_RocketInfo.milestone_row
function Elements.milestones_table.add_row(data_table, row)
    local labels = Elements.milestones_table.data[data_table]
    local name_label = data_table.add{
        type = "label",
        caption = { "exp-gui_rocket-info.data-caption-milestone-n", row.milestone },
        tooltip = { "exp-gui_rocket-info.data-tooltip-milestone-n", row.milestone },
    }
    name_label.style.padding = { 0, 2 }

    local value_label = data_table.add{
        type = "label",
        caption = row.value,
        tooltip = row.tooltip,
    }
    value_label.style.padding = { 0, 2 }

    labels[row.milestone] = value_label
end

--- Refresh the milestones table for a force, adding rows as new milestones become visible
--- @param data_table LuaGuiElement
--- @param force LuaForce
function Elements.milestones_table.refresh(data_table, force)
    local labels = Elements.milestones_table.data[data_table]
    for _, row in ipairs(compute_milestone_rows(force)) do
        local value_label = labels[row.milestone]
        if value_label then
            value_label.caption = row.value
            value_label.tooltip = row.tooltip
        else
            Elements.milestones_table.add_row(data_table, row)
        end
    end
end

--- @class ExpGui_RocketInfo.elements.progress_table.row
--- @field x LuaGuiElement
--- @field y LuaGuiElement
--- @field progress LuaGuiElement

--- @class ExpGui_RocketInfo.elements.progress_table.data
--- @field rows table<number, ExpGui_RocketInfo.elements.progress_table.row>
--- @field no_silos LuaGuiElement

--- Data table showing the build progress of each silo for a force
--- @class ExpGui_RocketInfo.elements.progress_table: ExpElement
--- @field data table<LuaGuiElement, ExpGui_RocketInfo.elements.progress_table.data>
--- @overload fun(parent: LuaGuiElement): LuaGuiElement
Elements.progress_table = Gui.define("rocket_info/progress_table")
    :track_all_elements()
    :draw(function(def, parent)
        --- @cast def ExpGui_RocketInfo.elements.progress_table
        local data_table = Gui.elements.scroll_table(parent, 215, 3)

        -- The no silos label lives next to the table inside the same collapsible scroll pane
        local no_silos = assert(data_table.parent).add{
            type = "label",
            caption = { "exp-gui_rocket-info.progress-no-silos" },
        }
        no_silos.style.padding = { 1, 2 }

        def.data[data_table] = { rows = {}, no_silos = no_silos }
        return data_table
    end) --[[ @as any ]]

--- Add a silo row to the progress table and store its labels
--- @param data_table LuaGuiElement
--- @param silo_data ExpGui_RocketInfo.silo_data
function Elements.progress_table.add_row(data_table, silo_data)
    local rows = Elements.progress_table.data[data_table].rows
    local entity = silo_data.entity
    local row_data = compute_progress_row(silo_data)
    local zoom_tooltip = config.progress.allow_zoom_to_map and { "exp-gui_rocket-info.progress-label-tooltip" } or nil

    local x = Elements.position_label(data_table, { caption = row_data.x, tooltip = zoom_tooltip, entity = entity })
    local y = Elements.position_label(data_table, { caption = row_data.y, tooltip = zoom_tooltip, entity = entity })
    local progress = data_table.add{
        type = "label",
        caption = row_data.caption,
        tooltip = row_data.tooltip,
    }
    progress.style.padding = { 0, 2 }
    progress.style.font_color = row_data.color

    rows[entity.unit_number] = { x = x, y = y, progress = progress }
end

--- Update an existing silo row to match the latest data
--- @param data_table LuaGuiElement
--- @param silo_data ExpGui_RocketInfo.silo_data
function Elements.progress_table.refresh_row(data_table, silo_data)
    local row = Elements.progress_table.data[data_table].rows[silo_data.entity.unit_number]
    local row_data = compute_progress_row(silo_data)
    row.x.caption = row_data.x
    row.y.caption = row_data.y
    row.progress.caption = row_data.caption
    row.progress.tooltip = row_data.tooltip
    row.progress.style.font_color = row_data.color
end

--- Remove a silo row from the progress table
--- @param data_table LuaGuiElement
--- @param unit_number number
function Elements.progress_table.remove_row(data_table, unit_number)
    local rows = Elements.progress_table.data[data_table].rows
    local row = rows[unit_number]
    if not row then return end
    rows[unit_number] = nil
    Gui.destroy_if_valid(row.x)
    Gui.destroy_if_valid(row.y)
    Gui.destroy_if_valid(row.progress)
end

--- Refresh the progress table for a force, reconciling rows with the current set of silos
--- @param data_table LuaGuiElement
--- @param force LuaForce
function Elements.progress_table.refresh(data_table, force)
    local silos = get_force_data(force).silos
    local data = Elements.progress_table.data[data_table]
    local rows = data.rows
    local seen = {}
    local has_silos = false

    for unit_number, silo_data in pairs(silos) do
        if not silo_data.entity.valid then
            -- Prune silos that are no longer valid
            silos[unit_number] = nil
        else
            has_silos = true
            seen[unit_number] = true
            if rows[unit_number] then
                Elements.progress_table.refresh_row(data_table, silo_data)
            else
                Elements.progress_table.add_row(data_table, silo_data)
            end
        end
    end

    -- Remove rows for silos that are no longer present
    for unit_number in pairs(rows) do
        if not seen[unit_number] then
            Elements.progress_table.remove_row(data_table, unit_number)
        end
    end

    data.no_silos.visible = not has_silos
    data_table.visible = has_silos
end

--- Add a collapsible section to a container and return its data table
--- @param container LuaGuiElement The container frame to add the section to
--- @param section_name string Used to select the locale keys for the header
--- @param table_define any The data table element define to add
--- @return LuaGuiElement
local function add_section(container, section_name, table_define)
    local header = Gui.elements.header(container, {
        caption = { "exp-gui_rocket-info.section-caption-" .. section_name },
        tooltip = { "exp-gui_rocket-info.section-tooltip-" .. section_name },
    })

    local data_table = table_define(container)

    -- The scroll pane is the parent of the table, it is what gets collapsed
    local scroll_pane = assert(data_table.parent)
    scroll_pane.visible = false
    Elements.toggle_section_button(header, scroll_pane)

    return data_table
end

--- Container added to the left gui flow
--- @class ExpGui_RocketInfo.elements.container: ExpElement
--- @field data table<LuaForce, ExpGui_RocketInfo.force_data>
Elements.container = Gui.define("rocket_info/container")
    :draw(function(def, parent)
        local container = Gui.elements.container(parent, 200)
        container.style.padding = 0

        local force = Gui.get_player(parent).force --[[ @as LuaForce ]]

        if config.stats.show_stats then
            Elements.stats_table.refresh(add_section(container, "stats", Elements.stats_table), force)
        end

        if config.milestones.show_milestones then
            Elements.milestones_table.refresh(add_section(container, "milestones", Elements.milestones_table), force)
        end

        if config.progress.show_progress then
            Elements.progress_table.refresh(add_section(container, "progress", Elements.progress_table), force)
        end

        return Gui.elements.container.get_root_element(container)
    end)

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
--- @param force LuaForce
local function refresh_force_stats(force)
    for _, data_table in Elements.stats_table:online_elements(force) do
        Elements.stats_table.refresh(data_table, force)
    end
    for _, data_table in Elements.milestones_table:online_elements(force) do
        Elements.milestones_table.refresh(data_table, force)
    end
end

--- Refresh the progress table for all online players on a force
--- @param force LuaForce
local function refresh_force_progress(force)
    for _, data_table in Elements.progress_table:online_elements(force) do
        Elements.progress_table.refresh(data_table, force)
    end
end

--- Record the launch and update the stats when a cargo pod finishes ascending
--- @param event EventData.on_cargo_pod_finished_ascending
local function on_cargo_pod_finished_ascending(event)
    local force = event.cargo_pod.force --[[ @as LuaForce ]]
    local rockets_launched = force.rockets_launched
    local force_data = get_force_data(force)

    -- Update the launch stats for the force
    local stats = force_data.stats
    if rockets_launched == 1 then
        stats.first_launch = event.tick
        stats.fastest_launch = event.tick
    elseif stats.last_launch and event.tick - stats.last_launch < (stats.fastest_launch or math.huge) then
        stats.fastest_launch = event.tick - stats.last_launch
    end

    stats.last_launch = event.tick

    -- Append the launch tick into the times array
    force_data.times[rockets_launched] = event.tick

    -- Discard the launch time that is no longer needed by any rolling average unless it is a milestone
    local remove_rocket = rockets_launched - largest_rolling_avg
    if remove_rocket > 0 and not table.array_contains(config.milestones, remove_rocket) then
        force_data.times[remove_rocket] = nil
    end

    refresh_force_stats(force)
    refresh_force_progress(force)
end

--- Mark a silo as awaiting reset when a launch is ordered
--- @param event EventData.on_rocket_launch_ordered
local function on_rocket_launch_ordered(event)
    local silo = event.rocket_silo
    local silo_data = get_force_data(silo.force --[[ @as LuaForce ]]).silos[silo.unit_number]
    if not silo_data then return end
    silo_data.launched = silo_data.launched + 1
    silo_data.awaiting_reset = true
    refresh_force_progress(silo.force --[[ @as LuaForce ]])
end

--- Add a silo to the force data when it is built
--- @param event EventData.on_built_entity | EventData.on_robot_built_entity | EventData.script_raised_built | EventData.script_raised_revive
local function on_built(event)
    local entity = event.entity
    if not entity.valid or entity.name ~= "rocket-silo" then return end
    get_force_data(entity.force --[[ @as LuaForce ]]).silos[entity.unit_number] = {
        entity = entity,
        launched = 0,
        awaiting_reset = false,
    }
    refresh_force_progress(entity.force --[[ @as LuaForce ]])
end

--- Refresh the progress for all forces that own at least one silo
local function refresh_all_progress()
    for _, force in pairs(game.forces) do
        if next(get_force_data(force).silos) then
            refresh_force_progress(force)
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
