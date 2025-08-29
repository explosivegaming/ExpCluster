--[[-- Gui - Research Milestones
Adds a gui for tracking research milestones
]]

local ExpUtil = require("modules/exp_util")
local Gui = require("modules/exp_gui")
local Roles = require("modules/exp_legacy/expcore/roles")
local config = require("modules/exp_legacy/config/research")

local table_to_json = helpers.table_to_json
local write_file = helpers.write_file
local string_format = string.format
local display_size = 8

--- @class ExpGui_ResearchMilestones.elements
local Elements = {}

local research_time_format = ExpUtil.format_time_factory{ format = "clock", hours = true, minutes = true, seconds = true }
local research_time_format_nil = research_time_format(nil)

local font_color = {
    neutral = { r = 1, g = 1, b = 1 },
    positive = { r = 0.3, g = 1, b = 0.3 },
    negative = { r = 1, g = 0.3, b = 0.3 },
}

--- @class ExpGui_ResearchMilestones.research_targets
--- @field index_lookup table<string, number>
--- @field target_times table<number, { name: string, target: number, label: LocalisedString }>
local research_targets = {
    index_lookup = {},
    target_times = {},
    max_start_index = 0,
    length = 0,
}

--- Select the mod set to be used for milestones
for _, mod_name in ipairs(config.mod_set_lookup) do
    if script.active_mods[mod_name] then
        config.mod_set = mod_name
        break
    end
end

do --- Calculate the research targets
    local research_index = 1
    local total_time = 0
    for name, time in pairs(config.milestone[config.mod_set]) do
        research_targets.index_lookup[name] = research_index
        total_time = total_time + time * 60

        research_targets.target_times[research_index] = {
            name = name,
            target = total_time,
            label = research_time_format(total_time),
        }

        research_index = research_index + 1
    end
    research_targets.length = research_index - 1
    research_targets.max_start_index = math.max(1, research_index - display_size)
end

--- Display label for the clock display
--- @class ExpGui_ResearchMilestones.elements.clock_label: ExpElement
--- @overload fun(parent: LuaGuiElement): LuaGuiElement
Elements.clock_label = Gui.define("research_milestones/clock_label")
    :track_all_elements()
    :draw{
        type = "label",
        caption = research_time_format_nil,
        style = "heading_2_label",
    } --[[ @as any ]]

--- Update the clock label for all online players
function Elements.clock_label.refresh_online()
    local current_time = research_time_format(game.tick)
    for _, clock_label in Elements.clock_label:online_elements() do
        clock_label.caption = current_time
    end
end

--- Label used for all parts of the table
--- @class ExpGui_ResearchMilestones.elements.milestone_table_label: ExpElement
--- @overload fun(parent: LuaGuiElement, caption: LocalisedString?, minimal_width: number?, horizontal_align: string?): LuaGuiElement
Elements.milestone_table_label = Gui.define("research_milestones/table_label")
    :draw{
        type = "label",
        caption = Gui.from_argument(1),
        style = "heading_2_label",
    }
    :style{
        minimal_width = Gui.from_argument(2, 70),
        horizontal_align = Gui.from_argument(3, "right"),
        font_color = font_color.neutral,
    } --[[ @as any ]]

--- @class ExpGui_ResearchMilestones.elements.milestone_table.row_elements
--- @field name LuaGuiElement
--- @field target LuaGuiElement
--- @field achieved LuaGuiElement
--- @field difference LuaGuiElement

--- @class ExpGui_ResearchMilestones.elements.milestone_table.row_data
--- @field name LocalisedString
--- @field target LocalisedString
--- @field achieved LocalisedString
--- @field difference LocalisedString
--- @field color Color

--- A table containing all of the current researches and their times / targets
--- @class ExpGui_ResearchMilestones.elements.milestone_table: ExpElement
--- @field data table<LuaGuiElement, ExpGui_ResearchMilestones.elements.milestone_table.row_elements[]>
--- @overload fun(parent: LuaGuiElement): LuaGuiElement
Elements.milestone_table = Gui.define("research_milestones/milestone_table")
    :track_all_elements()
    :draw(function(_, parent)
        local milestone_table = Gui.elements.scroll_table(parent, 390, 4)
        Elements.milestone_table_label(milestone_table, { "exp-gui_research-milestones.caption-name" }, 180, "left")
        Elements.milestone_table_label(milestone_table, { "exp-gui_research-milestones.caption-target" })
        Elements.milestone_table_label(milestone_table, { "exp-gui_research-milestones.caption-achieved" })
        Elements.milestone_table_label(milestone_table, { "exp-gui_research-milestones.caption-difference" })
        return milestone_table
    end) 
    :element_data{} --[[ @as any ]]

do local _row_data = {}
    --- @type ExpGui_ResearchMilestones.elements.milestone_table.row_data
    local empty_row_data = { color = font_color.positive }

    --- Get the row data for a force and research
    --- @param force LuaForce
    --- @param research_index number
    function Elements.milestone_table._clear_row_data_cache(force, research_index)
        local row_key = string_format("%s:%s", force.name, research_index)
        _row_data[row_key] = nil
    end

    --- Get the row data for a force and research
    --- @param force LuaForce
    --- @param research_index number
    --- @return ExpGui_ResearchMilestones.elements.milestone_table.row_data
    function Elements.milestone_table.calculate_row_data(force, research_index)
        local row_key = string_format("%s:%s", force.name, research_index)
        return _row_data[row_key] or Elements.milestone_table._calculate_row_data(force, research_index)
    end

    --- Calculate the row data for a force and research
    --- @param force LuaForce
    --- @param research_index number
    --- @return ExpGui_ResearchMilestones.elements.milestone_table.row_data
    function Elements.milestone_table._calculate_row_data(force, research_index)
        local row_key = string_format("%s:%s", force.name, research_index)

        -- If there is no target entry then return empty row data
        local entry = research_targets.target_times[research_index]
        if not entry then
            _row_data[row_key] = empty_row_data
            return empty_row_data
        end

        -- Otherwise calculate the row data
        assert(prototypes.technology[entry.name], "Invalid Research: " .. tostring(entry.name))
        local row_data = {} --- @cast row_data ExpGui_ResearchMilestones.elements.milestone_table.row_data
        row_data.name = { "exp-gui_research-milestones.caption-research-name", entry.name, prototypes.technology[entry.name].localised_name }
        row_data.target = entry.label

        local time = Elements.container.get_achieved_time(force, research_index)
        if not time then
            row_data.achieved = research_time_format_nil
            row_data.difference = research_time_format_nil
            row_data.color = font_color.neutral
        else
            row_data.achieved = research_time_format(time)
            local diff = time - entry.target
            row_data.difference = (diff < 0 and "-" or "+") .. research_time_format(math.abs(diff))
            row_data.color = (diff < 0 and font_color.positive) or font_color.negative
        end

        -- Store it in the cache for faster access next time
        _row_data[row_key] = row_data
        return row_data
    end
end

--- Adds a row to the milestone table
--- @param milestone_table LuaGuiElement
--- @param row_data ExpGui_ResearchMilestones.elements.milestone_table.row_data
function Elements.milestone_table.add_row(milestone_table, row_data)
    local rows = Elements.milestone_table.data[milestone_table]
    rows[#rows + 1] = {
        name = Elements.milestone_table_label(milestone_table, row_data.name, 180, "left"),
        target = Elements.milestone_table_label(milestone_table, row_data.target),
        achieved = Elements.milestone_table_label(milestone_table, row_data.achieved),
        difference = Elements.milestone_table_label(milestone_table, row_data.difference),
    }
end

--- Update a row to match the given data
--- @param milestone_table LuaGuiElement
--- @param row_index number
--- @param row_data ExpGui_ResearchMilestones.elements.milestone_table.row_data
function Elements.milestone_table.refresh_row(milestone_table, row_index, row_data)
    local row = Elements.milestone_table.data[milestone_table][row_index]
    row.name.caption = row_data.name
    row.target.caption = row_data.target
    row.achieved.caption = row_data.achieved
    row.difference.caption = row_data.difference
    row.difference.style.font_color = row_data.color
end

--- Update a row to match the given data for all players on a force
--- @param force LuaForce
--- @param row_index number
--- @param row_data ExpGui_ResearchMilestones.elements.milestone_table.row_data
function Elements.milestone_table.refresh_force_online_row(force, row_index, row_data)
    for _, milestone_table in Elements.milestone_table:online_elements(force) do
        Elements.milestone_table.refresh_row(milestone_table, row_index, row_data)
    end
end

--- Refresh all the labels on the table
--- @param milestone_table LuaGuiElement
function Elements.milestone_table.refresh(milestone_table)
    local force = Gui.get_player(milestone_table).force --[[ @as LuaForce ]]
    local start_index = Elements.container.calculate_starting_research_index(force)
    for row_index = 1, display_size do
        local row_data = Elements.milestone_table.calculate_row_data(force, start_index + row_index - 1)
        Elements.milestone_table.refresh_row(milestone_table, row_index, row_data)
    end
end

--- Refresh all tables for a player
function Elements.milestone_table.refresh_player(player)
    local force = player.force --[[ @as LuaForce ]]
    local start_index = Elements.container.calculate_starting_research_index(force)
    for _, milestone_table in Elements.milestone_table:online_elements(player) do
        for row_index = 1, display_size do
            local row_data = Elements.milestone_table.calculate_row_data(force, start_index + row_index - 1)
            Elements.milestone_table.refresh_row(milestone_table, row_index, row_data)
        end
    end
end

--- Refresh all tables for online players on a force
function Elements.milestone_table.refresh_force_online(force)
    local row_data = {}
    local start_index = Elements.container.calculate_starting_research_index(force)
    for row_index = 1, display_size do
        row_data[row_index] = Elements.milestone_table.calculate_row_data(force, start_index + row_index - 1)
    end

    for _, milestone_table in Elements.milestone_table:online_elements(force) do
        for row_index = 1, display_size do
            Elements.milestone_table.refresh_row(milestone_table, row_index, row_data[row_index])
        end
    end
end

--- Container added to the left gui flow
--- @class ExpGui_ResearchMilestones.elements.container: ExpElement
--- @field data table<LuaForce, number[]>
Elements.container = Gui.define("research_milestones/container")
    :draw(function(def, parent)
        local container = Gui.elements.container(parent)
        local header = Gui.elements.header(container, { caption = { "exp-gui_research-milestones.caption-main" } })
        local milestone_table = Elements.milestone_table(container)
        Elements.clock_label(header)

        local force = Gui.get_player(parent).force --[[ @as LuaForce ]]
        local start_index = Elements.container.calculate_starting_research_index(force)
        for research_index = start_index, start_index + display_size - 1 do
            local row_data = Elements.milestone_table.calculate_row_data(force, research_index)
            Elements.milestone_table.add_row(milestone_table, row_data)
        end

        return Gui.elements.container.get_root_element(container)
    end)
    :force_data{} --[[ @as any ]]

--- Set the achieved time for a force
--- @param force LuaForce
--- @param research_index number
--- @param time number
function Elements.container.set_achieved_time(force, research_index, time)
    Elements.milestone_table._clear_row_data_cache(force, research_index)
    Elements.container.data[force][research_index] = time
end

--- Get the achieved time for a force
--- @param force LuaForce
--- @param research_index number
--- @return number
function Elements.container.get_achieved_time(force, research_index)
    return Elements.container.data[force][research_index]
end

--- Calculate the starting research index for a force
--- @param force LuaForce
--- @return number
function Elements.container.calculate_starting_research_index(force)
    local force_data = Elements.container.data[force]
    local research_index = research_targets.length

    -- # does not work here because it returned the array alloc size
    for i = 1, research_targets.length do
        if not force_data[i] then
            research_index = i
            break
        end
    end

    return math.clamp(research_index - 2, 1, research_targets.max_start_index)
end

--- Append all research times to the research log
--- @param force LuaForce
function Elements.container.append_log_line(force)
    local result_data = {}

    local force_data = Elements.container.data[force]
    for name, research_index in pairs(research_targets.index_lookup) do
        result_data[name] = force_data[research_index]
    end

    write_file(config.file_name, table_to_json(result_data) .. "\n", true, 0)
end

--- Add the element to the left flow with a toolbar button
Gui.add_left_element(Elements.container, false)
Gui.toolbar.create_button{
    name = "toggle_research_milestones",
    left_element = Elements.container,
    sprite = "item/space-science-pack",
    tooltip = { "exp-gui_research-milestones.tooltip-main" },
    visible = function(player, element)
        return Roles.player_allowed(player, "gui/research")
    end
}

--- @param event EventData.on_research_finished
local function on_research_finished(event)
    local research_name = event.research.name
    local research_level = event.research.level
    local force = event.research.force

    -- Check if the log should be updated and print a message to chat
    if config.inf_res[config.mod_set][research_name] then
        local log_requirement = config.bonus_inventory.log[config.mod_set]
        if research_name == log_requirement.name and research_level == log_requirement.level + 1 then
            Elements.container.append_log_line(force)
        end

        if not (event.by_script) then
            game.print{ "exp-gui_research-milestones.notice-inf", research_time_format(game.tick), research_name, research_level - 1 }
        end
    elseif not (event.by_script) then
        game.print{ "exp-gui_research-milestones.notice", research_time_format(game.tick), research_name }
    end

    -- If the research does not have a milestone we don't need to update the gui
    local research_index = research_targets.index_lookup[research_name]
    if not research_index then
        return
    end

    -- Calculate the various difference indexes
    local previous_start_index = Elements.container.calculate_starting_research_index(force)
    Elements.container.set_achieved_time(force, research_index, event.tick)
    local start_index = Elements.container.calculate_starting_research_index(force)
    if start_index == previous_start_index then
        -- No change in start index so only need to update one row
        local row_index = research_index - start_index + 1
        if row_index > 0 and row_index <= 8 then
            local row_data = Elements.milestone_table.calculate_row_data(force, research_index)
            Elements.milestone_table.refresh_force_online_row(force, row_index, row_data)
        end
    else
        -- Start index changed so we need to refresh the table
        Elements.milestone_table.refresh_force_online(force)
    end
end

--- Force a refresh of the research table when a player joins or changes force
--- @param event EventData.on_player_joined_game | EventData.on_player_changed_force
local function refresh_for_player(event)
    Elements.milestone_table.refresh_player(Gui.get_player(event))
end

local e = defines.events

return {
    elements = Elements,
    events = {
        [e.on_research_finished] = on_research_finished,
        [e.on_player_joined_game] = refresh_for_player,
        [e.on_player_changed_force] = refresh_for_player,
    },
    on_nth_tick = {
        [60] = Elements.clock_label.refresh_online,
    }
}
