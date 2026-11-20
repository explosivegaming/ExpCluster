--[[-- Gui - Production Data
Adds a Gui for displaying item production stats
]]

local Gui = require("modules/exp_gui")
local Roles = require("modules/exp_roles")

--- @class ExpGui_ProductionStats.elements
local Elements = {}

--- The flow precision values in the same order as production_precision_dropdown.items
--- @type defines.flow_precision_index[]
local precision_indexes = {
    defines.flow_precision_index.five_seconds,
    defines.flow_precision_index.one_minute,
    defines.flow_precision_index.ten_minutes,
    defines.flow_precision_index.one_hour,
    defines.flow_precision_index.ten_hours,
}

local floor = math.floor
local min = math.min
local max = math.max
local format_string = string.format

--- The font colours used for number labels
local font_color = {
    positive = { r = 0.3, g = 1, b = 0.3 },
    negative = { r = 1, g = 0.3, b = 0.3 },
}

--- Format a number to include commas and a suffix
local function format_number(amount)
    if math.abs(amount) < 0.009 then
        return "0.00"
    end

    local scaler = 1
    local suffix = ""
    local suffix_list = {
        [" G"] = 1e9,
        [" M"] = 1e6,
        [" k"] = 1e3
    }

    -- Select which suffix and scaler to use
    for _suffix, _scaler in pairs(suffix_list) do
        if math.abs(amount) >= _scaler then
            scaler = _scaler
            suffix = _suffix
            break
        end
    end

    local formatted = string.format("%.2f%s", amount / scaler, suffix)
    -- Split into integer and fractional parts
    local integer_part, fractional_part = formatted:match("^(%-?%d+)%.(%d+)(.*)$")
    -- Add commas to integer part
    return string.format("%s.%s%s", (integer_part or formatted):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""):gsub("-,", "-"), fractional_part or "00", suffix)
end

--- Used to select the precision of the production table
Elements.precision_dropdown = Gui.define("production_stats/precision_dropdown")
    :draw{
        type = "drop-down",
        items = { "5s", "1m", "10m", "1h", "10h" },
        selected_index = 3,
    }
    :style{
        width = 80,
    }

--- Used to select the item to be displayed on a row
--- @class ExpGui_ProductionStats.elements.item_selector: ExpElement
--- @field data table<LuaGuiElement, { on_last_row: boolean, production_table: LuaGuiElement }>
--- @overload fun(parent: LuaGuiElement, production_table: LuaGuiElement): LuaGuiElement
Elements.item_selector = Gui.define("production_stats/item_selector")
    :draw{
        type = "choose-elem-button",
        elem_type = "item",
        style = "slot_button",
    }
    :style{
        size = 32,
    }
    :element_data{
        on_last_row = true,
        production_table = Gui.from_argument(1),
    }
    :on_elem_changed(function(def, player, element, event)
        --- @cast def ExpGui_ProductionStats.elements.item_selector
        local element_data = def.data[element]
        if not element.elem_value then
            if element_data.on_last_row then
                Elements.production_table.reset_row(element_data.production_table, element)
            else
                Elements.production_table.remove_row(element_data.production_table, element)
            end
        elseif element_data.on_last_row then
            element_data.on_last_row = false
            Elements.production_table.add_row(element_data.production_table)
        end
    end) --[[@as any]]
    
    
--- @class ExpGui_ProductionStats.elements.stat_bar.display_data
--- @field value number Fraction the bar is filled
--- @field caption string

--- Bar showing a statistic as a fraction with the values as its caption
--- @class ExpGui_ProductionStats.elements.stat_bar: ExpElement
--- @overload fun(parent: LuaGuiElement): LuaGuiElement
Elements.stat_bar = Gui.define("production_stats/stat_bar")
    :draw{
        type = "progressbar",
        caption = "",
        tooltip = {"exp-gui_production-stats.tooltip-per-second"},
        value = 0,
        style = "electric_satisfaction_statistics_progressbar",
    }
    :style{
        width = 250,
        font = "heading-2",
    } --[[@as any]]

--- A table that allows selecting items 
--- @class ExpGui_ProductionStats.elements.production_table: ExpElement
--- @field data table<LuaGuiElement, { precision_dropdown: LuaGuiElement, rows: ExpGui_ProductionStats.elements.stat_bar[] }>
--- @overload fun(parent: LuaGuiElement): LuaGuiElement
Elements.production_table = Gui.define("production_stats/production_table")
    :track_all_elements()
    :draw(function(def, parent)
        local scroll_table = Gui.elements.scroll_table(parent, 300, 2)

        def.data[scroll_table] = {
            precision_dropdown = Elements.precision_dropdown(scroll_table),
            rows = {},
        }

        return scroll_table
    end) --[[@as any]]

--- Calculate the row data for a production table
--- @param force LuaForce
--- @param surface LuaSurface
--- @param item_name string
--- @param precision_index defines.flow_precision_index
--- @return ExpGui_ProductionStats.elements.stat_bar.display_data
function Elements.production_table.calculate_row_data(force, surface, item_name, precision_index)
    local get_flow_count = force.get_item_production_statistics(surface).get_flow_count
    local production = floor(get_flow_count{ name = item_name, category = "input", precision_index = precision_index, count = false } / 6) / 10
    local consumption = floor(get_flow_count{ name = item_name, category = "output", precision_index = precision_index, count = false } / 6) / 10
    local net = production - consumption
    local ratio = production / max(consumption, 1)
    return {
        value = min(ratio, 1),
        caption = format_string(
            "%s / %s, %s,%.1f %%",
            format_number(production),
            format_number(consumption),
            format_number(net),
            ratio * 100
        ),
    }
end

--- A single row of a production table, the parent must be a production table
--- @param production_table LuaGuiElement
function Elements.production_table.add_row(production_table)
    local rows = Elements.production_table.data[production_table].rows
    local item_selector = Elements.item_selector(production_table, production_table)
    rows[item_selector.index] = {
        item_selector = item_selector,
        bar = Elements.stat_bar(production_table),
    }
end

--- Remove a row from a production table
--- @param production_table LuaGuiElement
--- @param item_selector LuaGuiElement
function Elements.production_table.remove_row(production_table, item_selector)
    local rows = Elements.production_table.data[production_table].rows
    local row = assert(rows[item_selector.index])
    rows[item_selector.index] = nil
    Gui.destroy_if_valid(item_selector)
    for _, element in pairs(row) do
        Gui.destroy_if_valid(element)
    end
end

--- Reset a row in a production table
--- @param production_table LuaGuiElement
--- @param item_selector LuaGuiElement
function Elements.production_table.reset_row(production_table, item_selector)
    local rows = Elements.production_table.data[production_table].rows
    local row = assert(rows[item_selector.index])
    row.bar.value = 0
    row.bar.caption = ""
end

--- Refresh the data on a row
--- @param production_table LuaGuiElement
--- @param item_selector LuaGuiElement
--- @param row_data ExpGui_ProductionStats.elements.stat_bar.display_data
function Elements.production_table.refresh_row(production_table, item_selector, row_data)
    local rows = Elements.production_table.data[production_table].rows
    local row = assert(rows[item_selector.index])
    row.bar.value = row_data.bar.value
    row.bar.caption = row_data.bar.caption
end

--- Refresh all online tables
function Elements.production_table.refresh_online()
    for player, production_table in Elements.production_table:online_elements() do
        local element_data = Elements.production_table.data[production_table]
        local precision_index = precision_indexes[element_data.precision_dropdown.selected_index]
        for _, row in pairs(element_data.rows) do
            local item_selector = row.item_selector
            local item_name = item_selector.elem_value --[[@as string?]]
            if item_name then
                local row_data = Elements.production_table.calculate_row_data(player.force --[[@as LuaForce]], player.surface, item_name, precision_index)
                Elements.production_table.refresh_row(production_table, item_selector, row_data)
            end
        end
    end
end

--- Container added to the left gui flow
Elements.container = Gui.define("production_stats/container")
    :draw(function(def, parent)
        local container = Gui.elements.container(parent)
        local production_table = Elements.production_table(container)
        Elements.production_table.add_row(production_table)
        return Gui.elements.container.get_root_element(container)
    end)

--- Add the element to the left flow with a toolbar button
Gui.add_left_element(Elements.container, false)
Gui.toolbar.create_button{
    name = "toggle_production_stats",
    left_element = Elements.container,
    sprite = "entity/assembling-machine-3",
    tooltip = { "exp-gui_production-stats.tooltip-main" },
    visible = function(player, element)
        return Roles.player_has_permission(player, "exp_scenario.gui.production")
    end
}

return {
    elements = Elements,
    on_nth_tick = {
        [60] = Elements.production_table.refresh_online,
    }
}
