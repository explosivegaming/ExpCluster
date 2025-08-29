--[[-- Gui - Science Info
Adds a science info gui that shows production usage and net for the different science packs as well as an eta
]]

local ExpUtil = require("modules/exp_util")
local Gui = require("modules/exp_gui")
local Colors = require("modules/exp_util/include/color")
local Roles = require("modules/exp_legacy/expcore/roles")
local config = require("modules/exp_legacy/config/gui/science")
local _format_number = require("util").format_number

local clock_time_format = ExpUtil.format_time_factory_locale{ format = "clock", hours = true, minutes = true, seconds = true }
local long_time_format = ExpUtil.format_time_factory_locale{ format = "long", hours = true, minutes = true, seconds = true }

local clock_time_format_nil = { "exp-gui_science-production.caption-eta-time", clock_time_format(nil) }
local long_time_format_nil = long_time_format(nil)

--- Remove invalid science packs, this can result from a certain mod not being loaded
for i = #config, 1, -1 do
    if not prototypes.item[config[i]] then
        table.remove(config, i)
    end
end

--- Returns the two parts used to format a number
--- @param value number
--- @return string, string
local function format_number(value)
    local rtn = _format_number(math.round(value, 1), true)
    local suffix = rtn:sub(-1)

    if value > 0 then
        rtn = "+" .. rtn
    elseif value == 0 and rtn:sub(1, 1) == "-" then
        rtn = rtn:sub(2)
    end

    if not tonumber(suffix) then
        return suffix, rtn:sub(1, -2)
    else
        return "", rtn
    end
end

--- @class ExpGui_ScienceProduction.elements
local Elements = {}

--- A pair of labels representing production of an idea
--- @class ExpGui_ScienceProduction.elements.production_label: ExpElement
--- @field data table<LuaGuiElement, LuaGuiElement>
--- @overload fun(parent: LuaGuiElement, production_label_strings: Elements.production_label.display_data): LuaGuiElement
Elements.production_label = Gui.define("science_production/production_label")
    :draw(function(def, parent, production_label_strings)
        --- @cast def ExpGui_ScienceProduction.elements.production_label
        --- @cast production_label_strings Elements.production_label.display_data

        -- Add the main value label
        local label = parent.add{
            type = "label",
            caption = production_label_strings.caption,
            tooltip = production_label_strings.tooltip,
        }

        local style = label.style
        style.font_color = production_label_strings.color
        style.horizontal_align = "right"
        style.minimal_width = 40

        -- Add the suffix label, this is intentionally being added to the parent
        local suffix = parent.add{
            type = "label",
            caption = { "exp-gui_science-production.caption-spm", production_label_strings.suffix },
            tooltip = production_label_strings.tooltip,
        }

        local suffix_style = suffix.style
        suffix_style.font_color = production_label_strings.color
        suffix_style.right_margin = 1

        def.data[label] = suffix
        return label
    end) --[[ @as any ]]

--- @class Elements.production_label.display_data
--- @field caption LocalisedString
--- @field suffix LocalisedString
--- @field tooltip LocalisedString
--- @field color Color

--- Get the data that is used with the production label
--- @param tooltip LocalisedString
--- @param value number
--- @param cutoff number
--- @param passive_value number?
--- @param display_data Elements.production_label.display_data?
--- @return Elements.production_label.display_data
function Elements.production_label.calculate_display_data(tooltip, value, cutoff, passive_value, display_data)
    local color = Colors.grey
    if value > cutoff then
        color = Colors.light_green
    elseif value < -cutoff then
        color = Colors.indian_red
    elseif value ~= 0 then
        color = Colors.orange
    elseif passive_value and passive_value > 0 then
        color = Colors.orange
    elseif passive_value and passive_value < 0 then
        color = Colors.indian_red
    end

    local suffix, caption = format_number(value)
    display_data = display_data or {}
    display_data.caption = caption
    display_data.suffix = suffix
    display_data.tooltip = tooltip
    display_data.color = color
    return display_data
end

--- Refresh a production label with the given production labels
--- @param production_label LuaGuiElement
--- @param display_data Elements.production_label.display_data
function Elements.production_label.refresh(production_label, display_data)
    production_label.caption = display_data.caption
    production_label.tooltip = display_data.tooltip
    production_label.style.font_color = display_data.color

    local suffix = Elements.production_label.data[production_label]
    suffix.caption = { "exp-gui_science-production.caption-spm", display_data.suffix }
    suffix.tooltip = display_data.tooltip
    suffix.style.font_color = display_data.color
end

--- Label used to signal that no packs have been produced by the force
--- @class ExpGui_ScienceProduction.elements.no_production_label: ExpElement
--- @overload fun(parent: LuaGuiElement): LuaGuiElement
Elements.no_production_label = Gui.define("science_production/no_production_label")
    :track_all_elements()
    :draw{
        type = "label",
        caption = { "exp-gui_science-production.caption-no-production" },
    }
    :style{
        padding = { 2, 4 },
        single_line = false,
        width = 200,
    } --[[ @as any ]]

--- Refresh a no production label
--- @param no_production_label LuaGuiElement
function Elements.no_production_label.refresh(no_production_label)
    local force = Gui.get_player(no_production_label).force --[[ @as LuaForce ]]
    no_production_label.visible = not Elements.container.has_production(force)
end

--- Refresh the no production label for all online players
function Elements.no_production_label.refresh_online()
    local force_data = {}
    for player, no_production_label in Elements.no_production_label:online_elements() do
        local force = player.force --[[ @as LuaForce ]]
        local visible = force_data[force.name]
        if visible == nil then
            visible = not Elements.container.has_production(force)
            force_data[player.force.name] = visible
        end
        no_production_label.visible = visible
    end
end

--- @class ExpGui_ScienceProduction.elements.science_table.row_elements
--- @field delta_flow LuaGuiElement
--- @field net_suffix LuaGuiElement
--- @field net LuaGuiElement
--- @field made LuaGuiElement
--- @field used LuaGuiElement
--- @field icon LuaGuiElement

--- @class ExpGui_ScienceProduction.elements.science_table.row_data
--- @field visible boolean
--- @field science_pack string
--- @field icon_style string
--- @field made Elements.production_label.display_data
--- @field used Elements.production_label.display_data
--- @field net Elements.production_label.display_data

--- A table containing all of the current science packs
--- @class ExpGui_ScienceProduction.elements.science_table: ExpElement
--- @field data table<LuaGuiElement, { [string]: ExpGui_ScienceProduction.elements.science_table.row_elements }>
--- @overload fun(parent: LuaGuiElement): LuaGuiElement
Elements.science_table = Gui.define("science_production/science_table")
    :track_all_elements()
    :draw(function(_, parent)
        local science_table = Gui.elements.scroll_table(parent, 190, 4)
        local no_production_label = Elements.no_production_label(science_table)
        Elements.no_production_label.refresh(no_production_label)
        science_table.style.column_alignments[3] = "right"
        return science_table
    end) 
    :element_data{} --[[ @as any ]]

--- Calculate the data needed to add or refresh a row
--- @param force LuaForce
--- @param science_pack string
--- @param row_data ExpGui_ScienceProduction.elements.science_table.row_data?
--- @return ExpGui_ScienceProduction.elements.science_table.row_data
function Elements.science_table.calculate_row_data(force, science_pack, row_data)
    local production = Elements.container.get_production_data(force)[science_pack]
    local total, one_hour = production.total, production.one_hour
    local one_minute, ten_minutes = production.one_minute, production.ten_minutes

    -- Get the icon style
    local icon_style = "slot_button"
    local flux = (one_minute.net / ten_minutes.net) - 1
    if one_minute.net > 0 and flux > -config.color_flux / 2 then
        icon_style = "slot_sized_button_green"
    elseif flux < -config.color_flux then
        icon_style = "slot_sized_button_red"
    elseif one_minute.made > 0 then
        icon_style = "yellow_slot_button"
    end

    -- Return the pack data
    row_data = row_data or {}
    row_data.visible = production.total.made > 0
    row_data.science_pack = science_pack
    row_data.icon_style = icon_style
    row_data.made = Elements.production_label.calculate_display_data(
        { "exp-gui_science-production.tooltip-made", total.made },
        one_minute.made, one_hour.made,
        nil, row_data.made
    )
    row_data.used = Elements.production_label.calculate_display_data(
        { "exp-gui_science-production.tooltip-used", total.used },
        -one_minute.used, one_hour.used,
        nil, row_data.used
    )
    row_data.net = Elements.production_label.calculate_display_data(
        { "exp-gui_science-production.tooltip-net", total.net },
        one_minute.net, one_minute.net > 0 and one_hour.net or 0,
        one_minute.made + one_minute.used, row_data.net
    )
    return row_data
end

--- Add a new row to the table
--- @param science_table LuaGuiElement
--- @param row_data ExpGui_ScienceProduction.elements.science_table.row_data
function Elements.science_table.add_row(science_table, row_data)
    if Elements.science_table.data[science_table][row_data.science_pack] then
        error("Cannot add multiple rows of the same type to the table")
    end

    -- Draw the icon for the science pack
    local visible = row_data.visible
    local icon_style = row_data.icon_style
    local pack_icon = science_table.add{
        type = "sprite-button",
        sprite = "item/" .. row_data.science_pack,
        tooltip = { "item-name." .. row_data.science_pack },
        style = icon_style,
        visible = visible,
    }

    -- Change the style of the icon
    local pack_icon_style = pack_icon.style
    pack_icon.ignored_by_interaction = true
    pack_icon_style.height = 55

    -- Draw the delta flow
    local delta_flow = science_table.add{
        type = "frame",
        style = "bordered_frame",
        visible = visible,
    }
    delta_flow.style.padding = { 0, 3 }

    -- Draw the delta flow table
    local delta_table = delta_flow.add{
        type = "table",
        column_count = 2,
    }
    delta_table.style.padding = 0
    delta_table.style.column_alignments[1] = "right"

    -- Draw the net production label
    local net = Elements.production_label(science_table, row_data.net)
    local net_suffix = Elements.production_label.data[net]
    net_suffix.visible = visible
    net.visible = visible

    -- Draw the other two production labels
    Elements.science_table.data[science_table][row_data.science_pack] = {
        made = Elements.production_label(delta_table, row_data.made),
        used = Elements.production_label(delta_table, row_data.used),
        delta_flow = delta_flow,
        net_suffix = net_suffix,
        icon = pack_icon,
        net = net,
    }
end

--- Refresh a row on a table
--- @param science_table LuaGuiElement
--- @param row_data ExpGui_ScienceProduction.elements.science_table.row_data
function Elements.science_table.refresh_row(science_table, row_data)
    if not row_data.visible then
        return -- Rows start as not visible, then once visible they remain always visible
    end

    local row = assert(Elements.science_table.data[science_table][row_data.science_pack])

    -- Update the icon
    local icon = row.icon
    icon.style = row_data.icon_style
    icon.style.height = 55

    -- Update the element visibility
    row.net_suffix.visible = true
    row.delta_flow.visible = true
    row.net.visible = true
    icon.visible = true

    -- Update the production labels
    Elements.production_label.refresh(row.net, row_data.net)
    Elements.production_label.refresh(row.made, row_data.made)
    Elements.production_label.refresh(row.used, row_data.used)
end

--- @type table<string, { [string]: ExpGui_ScienceProduction.elements.science_table.row_data }>
do local _row_data = {}
    --- Refresh the production tables for all online players
    function Elements.science_table.refresh_online()
        -- Refresh the row data for online forces
        for _, force in pairs(game.forces) do
            if next(force.connected_players) then
                local row_data = _row_data[force.name] or {}
                _row_data[force.name] = row_data
                for i, science_pack in ipairs(config) do
                    --- @cast science_pack any
                    row_data[i] = Elements.science_table.calculate_row_data(force, science_pack, row_data[i])
                end
            end
        end

        -- Update the tables
        for player, science_table in Elements.science_table:online_elements() do
            for _, row_data in ipairs(_row_data[player.force.name]) do
                Elements.science_table.refresh_row(science_table, row_data)
            end
        end
    end
end

--- Displays the eta until research completion
--- @class ExpGui_ScienceProduction.elements.eta_label: ExpElement
--- @overload fun(parent: LuaGuiElement): LuaGuiElement
Elements.eta_label = Gui.define("science_production/eta_label")
    :track_all_elements()
    :draw{
        type = "label",
        caption = clock_time_format_nil,
        tooltip = long_time_format_nil,
        style = "frame_title",
    } --[[ @as any ]]

--- @class Elements.eta_label.display_data
--- @field caption LocalisedString
--- @field tooltip LocalisedString

--- Avoid creating new tables for nil time
--- @type Elements.eta_label.display_data
local _nil_eta_strings = {
    caption = clock_time_format_nil,
    tooltip = long_time_format_nil,
}

--- Calculate the eta time for a force to complete a research
--- @param force LuaForce
--- @return Elements.eta_label.display_data
function Elements.eta_label.calculate_display_data(force)
    -- If there is no current research then return no research
    local research = force.current_research
    if not research then
        return _nil_eta_strings
    end

    local limit = 0
    local progress = force.research_progress
    local remaining = research.research_unit_count * (1 - progress)

    -- Check for the limiting science pack
    local force_data = Elements.container.get_production_data(force)
    for _, ingredient in pairs(research.research_unit_ingredients) do
        local pack_name = ingredient.name
        local required = ingredient.amount * remaining
        local production = force_data[pack_name].one_minute
        local time = production.used == 0 and -1 or 3600 * required / production.used
        if limit < time then
            limit = time
        end
    end

    -- Return the caption and tooltip
    return limit == 0 and _nil_eta_strings or {
        caption = { "exp-gui_science-production.caption-eta-time", clock_time_format(limit) },
        tooltip = long_time_format(limit),
    }
end

--- Refresh an eta label
--- @param eta_label LuaGuiElement
function Elements.eta_label.refresh(eta_label)
    local force = Gui.get_player(eta_label).force --[[ @as LuaForce ]]
    local display_data = Elements.eta_label.calculate_display_data(force)
    eta_label.caption = display_data.caption
    eta_label.tooltip = display_data.tooltip
end

--- @type Elements.eta_label.display_data
do local _display_data = {}
    --- Refresh the eta label for all online players
    function Elements.eta_label.refresh_online()
        -- Refresh the row data for online forces
        for _, force in pairs(game.forces) do
            if next(force.connected_players) then
                _display_data[force.name] = Elements.eta_label.calculate_display_data(force)
            end
        end

        -- Update the eta labels
        for player, eta_label in Elements.eta_label:online_elements() do
            local display_data = _display_data[player.force.name]
            eta_label.caption = display_data.caption
            eta_label.tooltip = display_data.tooltip
        end
    end
end

--- Container added to the left gui flow
--- @class ExpGui_ScienceProduction.elements.container: ExpElement
Elements.container = Gui.define("science_production/container")
    :draw(function(def, parent)
        local container = Gui.elements.container(parent)
        Gui.elements.header(container, { caption = { "exp-gui_science-production.caption-main" } })

        local force = Gui.get_player(parent).force --[[ @as LuaForce ]]
        local science_table = Elements.science_table(container)
        for _, science_pack in ipairs(config) do
            --- @cast science_pack any
            local row_data = Elements.science_table.calculate_row_data(force, science_pack)
            Elements.science_table.add_row(science_table, row_data)
        end

        if config.show_eta then
            local footer = Gui.elements.footer(container, {
                caption = { "exp-gui_science-production.caption-eta" },
                tooltip = { "exp-gui_science-production.tooltip-eta" },
            })

            local eta_label = Elements.eta_label(footer)
            Elements.eta_label.refresh(eta_label)
        end

        return Gui.elements.container.get_root_element(container)
    end) --[[ @as any ]]

--- Cached mostly because they are long names
local _fp_one_minute = defines.flow_precision_index.one_minute
local _fp_ten_minutes = defines.flow_precision_index.ten_minutes
local _fp_one_hour = defines.flow_precision_index.one_hour

--- @alias ExpGui_ScienceProduction._item_data { made: number, used: number, net: number }

--- @class ExpGui_ScienceProduction.item_production_data
--- @field total ExpGui_ScienceProduction._item_data
--- @field one_minute ExpGui_ScienceProduction._item_data
--- @field ten_minutes ExpGui_ScienceProduction._item_data
--- @field one_hour ExpGui_ScienceProduction._item_data

--- @type table<string, { [string]: ExpGui_ScienceProduction.item_production_data }>
do local _production_data = {}

    --- Get the production stats for a force
    --- @param flow_stats any
    --- @param item_name string
    --- @param precision defines.flow_precision_index
    --- @return ExpGui_ScienceProduction._item_data
    local function get_production(flow_stats, item_name, precision)
        local made, used = 0, 0
        for _, get_flow_count in pairs(flow_stats) do
            made = made + get_flow_count{ name = item_name, category = "input", precision_index = precision }
            used = used + get_flow_count{ name = item_name, category = "output", precision_index = precision }
        end
        return { made = made, used = used, net = made - used }
    end

    --- Get the production data for a force
    --- @param force LuaForce
    --- @return { [string]: ExpGui_ScienceProduction.item_production_data }
    function Elements.container.get_production_data(force)
        return _production_data[force.name] or Elements.container.calculate_production_data(force)
    end

    --- Calculate the production data for a force
    --- @param force LuaForce
    --- @return { [string]: ExpGui_ScienceProduction.item_production_data }
    function Elements.container.calculate_production_data(force)
        -- Setup the force data
        local force_data = _production_data[force.name] or {}
        _production_data[force.name] = force_data

        -- Cache the various stats calls for the force
        local flow_stats = {}
        local production_stats = {}
        local get_stats = force.get_item_production_statistics
        for name, surface in pairs(game.surfaces) do
            local stats = get_stats(surface)
            flow_stats[name] = stats.get_flow_count
            production_stats[name] = stats
        end

        -- Calculate the production data for each science pack
        for _, science_pack in ipairs(config) do
            --- @cast science_pack any
            local made, used = 0, 0
            for _, stats in pairs(production_stats) do
                made = made + stats.get_input_count(science_pack)
                used = used + stats.get_output_count(science_pack)
            end
            local item_data = force_data[science_pack] or {}
            force_data[science_pack] = item_data
            item_data.total = { made = made, used = used, net = made - used }
            item_data.one_minute = get_production(flow_stats, science_pack, _fp_one_minute)
            item_data.ten_minutes = get_production(flow_stats, science_pack, _fp_ten_minutes)
            item_data.one_hour = get_production(flow_stats, science_pack, _fp_one_hour)
        end

        return force_data
    end
end

--- Returns true if any science packs have been produced by a force
--- @param force LuaForce
--- @return boolean
function Elements.container.has_production(force)
    local production_data = Elements.container.get_production_data(force)
    for _, data in pairs(production_data) do
        if data.total.made > 0 then
            return true
        end
    end
    return false
end

--- Refresh the production data for all online forces, must be called before any other refresh
function Elements.container.refresh_online()
    for _, force in pairs(game.forces) do
        if next(force.connected_players) then
            Elements.container.calculate_production_data(force)
        end
    end
end

--- Add the element to the left flow with a toolbar button
Gui.add_left_element(Elements.container, false)
Gui.toolbar.create_button{
    name = "toggle_science_info",
    left_element = Elements.container,
    sprite = "entity/lab",
    tooltip = { "exp-gui_science-production.tooltip-main" },
    visible = function(player, element)
        return Roles.player_allowed(player, "gui/science-info")
    end
}

--- Updates the gui every 1 second
local function update_gui()
    Elements.container.refresh_online()
    Elements.eta_label.refresh_online()
    Elements.science_table.refresh_online()
    Elements.no_production_label.refresh_online()
end

return {
    elements = Elements,
    on_nth_tick = {
        [60] = update_gui,
    }
}
