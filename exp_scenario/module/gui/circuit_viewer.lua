--[[-- Gui - Circuit Viewer
View circuit network remotely
]]

local Gui = require("modules/exp_gui")
local Roles = require("modules/exp_roles")
local format_number = require("util").format_number

--- @class ExpGui_CircuitViewer.elements
local Elements = {}

--- The font colours used for number labels
local font_color = {
    r = { r = 1, g = 0.3, b = 0.3 },
    g = { r = 0.3, g = 1, b = 0.3 },
}

local format_string = string.format

--- Used to select the item to be displayed on a row
--- @class ExpGui_CircuitViewer.elements.item_selector: ExpElement
--- @field data table<LuaGuiElement, { on_last_row: boolean, circuit_table: LuaGuiElement }>
--- @overload fun(parent: LuaGuiElement, circuit_table: LuaGuiElement): LuaGuiElement
Elements.item_selector = Gui.define("circuit_viewer/item_selector")
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
        circuit_table = Gui.from_argument(1),
    }
    :on_elem_changed(function(def, player, element, event)
        --- @cast def ExpGui_CircuitViewer.elements.item_selector
        local element_data = def.data[element]
        if not element.elem_value then
            if element_data.on_last_row then
                Elements.circuit_table.reset_row(element_data.circuit_table, element)
            else
                Elements.circuit_table.remove_row(element_data.circuit_table, element)
            end
        elseif element_data.on_last_row then
            element_data.on_last_row = false
            Elements.circuit_table.add_row(element_data.circuit_table)
        end
    end) --[[@as any]]
    
--- Label used for every element in the circuit table
Elements.table_label = Gui.define("circuit_viewer/table_label")
    :draw{
        type = "label",
        caption = Gui.from_argument(1, "0.00"),
        style = Gui.from_argument(2),
    }
    :style{
        horizontal_align = "right",
        minimal_width = 60,
    }

--- @class ExpGui_CircuitViewer.elements.circuit_table.row_elements
--- @field item_selector LuaGuiElement
--- @field red LuaGuiElement
--- @field green LuaGuiElement
--- @field total LuaGuiElement

--- @class ExpGui_CircuitViewer.elements.circuit_table.row_data
--- @field red LocalisedString
--- @field green LocalisedString
--- @field total LocalisedString

--- A table that allows selecting items 
--- @class ExpGui_CircuitViewer.elements.circuit_table: ExpElement
--- @field data table<LuaGuiElement, { network: LuaGuiElement, rows: ExpGui_CircuitViewer.elements.circuit_table.row_elements[] }>
--- @overload fun(parent: LuaGuiElement): LuaGuiElement
Elements.circuit_table = Gui.define("circuit_viewer/circuit_table")
    :track_all_elements()
    :draw(function(def, parent)
        local scroll_table = Gui.elements.scroll_table(parent, 304, 4)
        local display_alignments = assert(scroll_table.style.column_alignments)
        for i = 2, 4 do
            display_alignments[i] = "right"
        end

        def.data[scroll_table] = {
            network = Elements.table_label(scroll_table, "0", "heading_2_label"),
            rows = {},
        }

        Elements.table_label(scroll_table, "[item=red-wire]", "heading_2_label")
        Elements.table_label(scroll_table, "[item=green-wire]", "heading_2_label")
        Elements.table_label(scroll_table, "[item=medium-pole]", "heading_2_label")

        return scroll_table
    end) --[[@as any]]

--- Calculate the row data for a circuit table
--- @param force LuaForce
--- @param surface LuaSurface
--- @param item_name string
--- @param network_index number
--- @return ExpGui_CircuitViewer.elements.circuit_table.row_data
function Elements.circuit_table.calculate_row_data(force, surface, item_name, network_index)
    local get_flow_count = force.get_item_production_statistics(surface).get_flow_count
    local red = math.floor(get_flow_count{ name = item_name, category = "input", precision_index = precision_index, count = false } / 6) / 10
    local green = math.floor(get_flow_count{ name = item_name, category = "output", precision_index = precision_index, count = false } / 6) / 10
    local total = red + green
    return {
        red = format_number(red),
        green = format_number(green),
        total = format_number(total),
    }
end

--- A single row of a circuit table, the parent must be a circuit table
--- @param circuit_table LuaGuiElement
function Elements.circuit_table.add_row(circuit_table)
    local rows = Elements.circuit_table.data[circuit_table].rows
    local item_selector = Elements.item_selector(circuit_table, circuit_table)
    local red = Elements.table_label(circuit_table, "")
    red.style.font_color = font_color.r
    local green = Elements.table_label(circuit_table, "")
    row.green.style.font_color = font_color.g
    rows[item_selector.index] = {
        item_selector = item_selector,
        red = red,
        green = green,
        total = Elements.table_label(circuit_table, ""),
    }
end

--- Remove a row from a circuit table
--- @param circuit_table LuaGuiElement
--- @param item_selector LuaGuiElement
function Elements.circuit_table.remove_row(circuit_table, item_selector)
    local rows = Elements.circuit_table.data[circuit_table].rows
    local row = assert(rows[item_selector.index])
    rows[item_selector.index] = nil
    Gui.destroy_if_valid(item_selector)
    for _, element in pairs(row) do
        Gui.destroy_if_valid(element)
    end
end

--- Reset a row in a circuit table
--- @param circuit_table LuaGuiElement
--- @param item_selector LuaGuiElement
function Elements.circuit_table.reset_row(circuit_table, item_selector)
    local rows = Elements.circuit_table.data[circuit_table].rows
    local row = assert(rows[item_selector.index])
    row.red.caption = ""
    row.red.style.font_color = font_color.r
    row.green.caption = ""
    row.green.style.font_color = font_color.g
    row.total.caption = ""
end

--- Refresh the data on a row
--- @param circuit_table LuaGuiElement
--- @param item_selector LuaGuiElement
--- @param row_data ExpGui_CircuitViewer.elements.circuit_table.row_data
function Elements.circuit_table.refresh_row(circuit_table, item_selector, row_data)
    local rows = Elements.circuit_table.data[circuit_table].rows
    local row = assert(rows[item_selector.index])
    row.red.caption = row_data.red
    row.green.caption = row_data.green
    row.total.caption = row_data.total
end

--- Refresh all online tables
function Elements.circuit_table.refresh_online()
    for player, circuit_table in Elements.circuit_table:online_elements() do
        local element_data = Elements.circuit_table.data[circuit_table]
        local network_index = element_data.network.caption
        for _, row in pairs(element_data.rows) do
            local item_selector = row.item_selector
            local item_name = item_selector.elem_value --[[@as string?]]
            if item_name then
                local row_data = Elements.circuit_table.calculate_row_data(player.force --[[@as LuaForce]], player.surface, item_name, network_index)
                Elements.circuit_table.refresh_row(circuit_table, item_selector, row_data)
            end
        end
    end
end

--- Container added to the left gui flow
Elements.container = Gui.define("circuit_viewer/container")
    :draw(function(def, parent)
        local container = Gui.elements.container(parent)
        local circuit_table = Elements.circuit_table(container)
        Elements.circuit_table.add_row(circuit_table)
        return Gui.elements.container.get_root_element(container)
    end)

--- Add the element to the left flow with a toolbar button
Gui.add_left_element(Elements.container, false)
Gui.toolbar.create_button{
    name = "toggle_circuit_viewer",
    left_element = Elements.container,
    sprite = "entity/combinator-decider",
    tooltip = { "exp-gui_circuit_viewer.tooltip-main" },
    visible = function(player, element)
        return Roles.player_has_permission(player, "exp_scenario.gui.production")
    end
}

return {
    elements = Elements,
    on_nth_tick = {
        [60] = Elements.circuit_table.refresh_online,
    }
}
