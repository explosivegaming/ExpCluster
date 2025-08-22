--[[-- Gui - Production Data
Adds a Gui for displaying item production stats
]]

local Gui = require("modules/exp_gui")
local Roles = require("modules/exp_legacy/expcore/roles")

--- @class ExpGui_ProductionStats.elements
local Elements = {}

--- The flow precision values in the same order as production_precision_dropdown.items
local precision_values = {
    defines.flow_precision_index.five_seconds,
    defines.flow_precision_index.one_minute,
    defines.flow_precision_index.ten_minutes,
    defines.flow_precision_index.one_hour,
    defines.flow_precision_index.ten_hours,
}

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

--- @class ExpGui_ProductionStats.elements.item_selector.labels
--- @field production LuaGuiElement
--- @field consumption LuaGuiElement
--- @field net LuaGuiElement

--- Used to select the item to be displayed on a row
--- @class ExpGui_ProductionStats.elements.item_selector: ExpElement
--- @field data table<LuaGuiElement, { labels: ExpGui_ProductionStats.elements.item_selector.labels, on_last_row: boolean }>
--- @overload fun(parent: LuaGuiElement, labels: ExpGui_ProductionStats.elements.item_selector.labels): LuaGuiElement
Elements.item_selector = Gui.define("production_stats/item_selector")
    :track_all_elements()
    :draw{
        type = "choose-elem-button",
        elem_type = "item",
        style = "slot_button",
    }
    :style{
        size = 32,
    }
    :element_data{
        labels = Gui.from_argument(1),
        on_last_row = true,
    }
    :on_elem_changed(function(def, player, element, event)
        --- @cast def ExpGui_ProductionStats.elements.item_selector
        local element_data = def.data[element]
        if not element.elem_value then
            if element_data.on_last_row then
                -- This is the last, so reset the labels to 0
                local labels = element_data.labels
                labels.production.caption = "0.00"
                labels.consumption.caption = "0.00"
                labels.net.caption = "0.00"
                labels.net.style.font_color = font_color.positive
            else
                -- This is not the last row, so destroy it
                Gui.destroy_if_valid(element)
                for _, label in pairs(element_data.labels) do
                    Gui.destroy_if_valid(label)
                end
            end
        elseif element.elem_value and element_data.on_last_row then
            -- New item selected on the last row, so make a new row
            element_data.on_last_row = false
            Elements.production_table.add_row(element.parent)
        end
    end) --[[ @as any ]]
    
--- Label used for every element in the production table
Elements.table_label = Gui.define("production_stats/table_label")
    :draw{
        type = "label",
        caption = Gui.from_argument(1, "0.00"),
        tooltip = Gui.from_argument(2),
        style = Gui.from_argument(3),
    }
    :style{
        horizontal_align = "right",
        minimal_width = 60,
    }

--- A table that allows selecting items 
--- @class ExpGui_ProductionStats.elements.production_table: ExpElement
Elements.production_table = Gui.define("production_stats/production_table")
    :draw(function(def, parent)
        local scroll_table = Gui.elements.scroll_table(parent, 304, 4)
        local display_alignments = scroll_table.style.column_alignments
        for i = 2, 4 do
            display_alignments[i] = "right"
        end

        def.data[scroll_table] = Elements.precision_dropdown(scroll_table)
        Elements.table_label(scroll_table, { "gui-production.production" }, { "exp-gui_production-stats.tooltip-per-second" }, "heading_2_label")
        Elements.table_label(scroll_table, { "gui-production.consumption" }, { "exp-gui_production-stats.tooltip-per-second" }, "heading_2_label")
        Elements.table_label(scroll_table, { "exp-gui_production-stats.caption-net" }, { "exp-gui_production-stats.tooltip-per-second" }, "heading_2_label")

        return scroll_table
    end)

--- A single row of a production table, the parent must be a production table
--- @param production_table LuaGuiElement
function Elements.production_table.add_row(production_table)
    local labels = {} --- @cast labels ExpGui_ProductionStats.elements.item_selector.labels
    Elements.item_selector(production_table, labels)
    labels.production = Elements.table_label(production_table, "0.00")
    labels.consumption = Elements.table_label(production_table, "0.00")
    labels.net = Elements.table_label(production_table, "0.00")
end

--- Container added to the left gui flow
Elements.container = Gui.define("production_stats/container")
    :draw(function(def, parent)
        local container = Gui.elements.container(parent)
        local production_table = Elements.production_table(container)
        Elements.production_table.add_row(production_table)
        return container.parent
    end)

--- Add the element to the left flow with a toolbar button
Gui.add_left_element(Elements.container, false)
Gui.toolbar.create_button{
    name = "toggle_production_stats",
    left_element = Elements.container,
    sprite = "entity/assembling-machine-3",
    tooltip = { "exp-gui_production-stats.tooltip-main" },
    visible = function(player, element)
        return Roles.player_allowed(player, "gui/production")
    end
}

--- Update all table rows with the latest production values
local function update_table_rows()
    for player, item_selector in Elements.item_selector:online_elements() do
        local item_name = item_selector.elem_value --[[ @as string? ]]
        if item_name then
            -- An item is selected, so get the flow rate and update label captions
            local element_data = Elements.item_selector.data[item_selector]
            local precision_dropdown = Elements.production_table.data[item_selector.parent]
            local precision_value = precision_values[precision_dropdown.selected_index]

            local get_flow_count = player.force.get_item_production_statistics(player.surface).get_flow_count -- Allow remote view
            local production = math.floor(get_flow_count{ name = item_name, category = "input", precision_index = precision_value, count = false } / 6) / 10
            local consumption = math.floor(get_flow_count{ name = item_name, category = "output", precision_index = precision_value, count = false } / 6) / 10
            local net = production - consumption

            local labels = element_data.labels
            labels.production.caption = format_number(production)
            labels.consumption.caption = format_number(consumption)
            labels.net.caption = format_number(net)
            labels.net.style.font_color = net < 0 and font_color.negative or font_color.positive
        end
    end
end

return {
    elements = Elements,
    on_nth_tick = {
        [60] = update_table_rows,
    }
}
