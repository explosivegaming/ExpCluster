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
        elem_type = "signal",
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
        caption = Gui.from_argument(1, ""),
        style = Gui.from_argument(2),
    }
    :style{
        horizontal_align = "right",
        minimal_width = 60,
    }

--- Button used to display the location of entity
--- @class ExpGui_CircuitViewer.elements.view_button: ExpElement
--- @field data table<LuaGuiElement, ExpGui_CircuitViewer.elements.view_button.element_data>
--- @overload fun(parent: LuaGuiElement, controls: LuaGuiElement): LuaGuiElement
Elements.view_button = Gui.define("circuit_viewer/view_button")
    :draw{
        type = "button",
        caption = {"exp-gui_circuit_viewer.view"},
    }
    :style{
        width = 100,
    }
    :element_data{
        controls = Gui.from_argument(1),
    }
    :on_click(function(def, parent, view_button)
        --- @cast def ExpGui_CircuitViewer.elements.view_button
        game.players[parent.player_index].print(def.data[view_button].entity.gps_tag)
    end) --[[@as any]]
    
--- Button used to set the entity to reference the network
--- @class ExpGui_CircuitViewer.elements.set_button: ExpElement
--- @field data table<LuaGuiElement, LuaEntity>
--- @overload fun(parent: LuaGuiElement, controls: LuaGuiElement): LuaGuiElement
Elements.set_button = Gui.define("circuit_viewer/set_button")
    :draw{
        type = "button",
        caption = {"exp-gui_circuit_viewer.set"},
    }
    :style{
        width = 100,
    }
    :element_data{
        controls = Gui.from_argument(1),
    }
    :on_click(function(def, parent, set_button)
        --- @cast def ExpGui_CircuitViewer.elements.set_button
        def.data[set_button].entity = parent.entity
    end) --[[@as any]]

--- @class ExpGui_CircuitViewer.elements.circuit_table.row_elements
--- @field item_selector LuaGuiElement
--- @field red LuaGuiElement
--- @field green LuaGuiElement
--- @field total LuaGuiElement

--- @class ExpGui_CircuitViewer.elements.circuit_table.row_data
--- @field red LocalisedString
--- @field green LocalisedString
--- @field total LocalisedString

--- A relative screen that set the current viewer to the entity 
--- @class ExpGui_CircuitViewer.elements.circuit_frame: ExpElement
--- @overload fun(parent: LuaGuiElement, relative_gui: defines.relative_gui_type, entity_type: string): LuaGuiElement
Elements.circuit_frame = Gui.define("circuit_viewer/circuit_frame")
    :draw(function(def, parent)
        local frame = parent.gui.relative.add({
            type = "frame",
            name = "circuit_viewer/circuit_frame",
            anchor = {
                gui = relative_gui,
                position = defines.relative_gui_position.right,
                type = entity_type,
            }})
        Elements.table_label(frame, { "exp-gui_circuit_viewer.tooltip-main" }, "heading_2_label")
        Elements.set_button(frame)
        return frame
    end) --[[@as any]]

--- A table that allows selecting items 
--- @class ExpGui_CircuitViewer.elements.circuit_table: ExpElement
--- @field data table<LuaGuiElement, { entity: LuaEntity, anchor: LuaGuiElement[], rows: ExpGui_CircuitViewer.elements.circuit_table.row_elements[] }>
--- @overload fun(parent: LuaGuiElement): LuaGuiElement
Elements.circuit_table = Gui.define("circuit_viewer/circuit_table")
    :track_all_elements()
    :draw(function(def, parent)
        local scroll_table = Gui.elements.scroll_table(parent, 300, 4)
        Elements.view_button(scroll_table, scroll_table)
        Elements.table_label(scroll_table, "[item=red-wire]", "heading_2_label")
        Elements.table_label(scroll_table, "[item=green-wire]", "heading_2_label")
        Elements.table_label(scroll_table, "[item=medium-pole]", "heading_2_label")

        def.data[scroll_table] = {
            entity = nil,
            anchor = {
                Elements.circuit_frame(scroll_table, defines.relative_gui_type.arithmetic_combinator_gui, "arithmetic-combinator"),
                Elements.circuit_frame(scroll_table, defines.relative_gui_type.constant_combinator_gui, "constant-combinator"),
                Elements.circuit_frame(scroll_table, defines.relative_gui_type.decider_combinator_gui, "decider-combinator"),
                Elements.circuit_frame(scroll_table, defines.relative_gui_type.display_panel_gui, "display-panel")
            },
            rows = {},
        }

        return scroll_table
    end) --[[@as any]]

--- Calculate the row data for a circuit table
--- @param entity LuaEntity
--- @param value string
--- @return ExpGui_CircuitViewer.elements.circuit_table.row_data
function Elements.circuit_table.calculate_row_data(entity, item_name)
    local control = entity.get_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]]
    local red = control.get_circuit_network(defines.wire_connector_id.circuit_red)
    local green = control.get_circuit_network(defines.wire_connector_id.circuit_green)
    red = red.get_signal(value)
    green = green.get_signal(value)
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
            local value = item_selector.elem_value --[[@as string?]]
            local entity = element_data.entity
            if entity and value then
                local row_data = Elements.circuit_table.calculate_row_data(element_data.entity, value)
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
    sprite = "item/decider-combinator",
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
