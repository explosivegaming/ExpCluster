--[[-- Gui - Autofill
Adds a config menu for setting autofill of placed entities
]]

local Gui = require("modules/exp_gui")
local Roles = require("modules.exp_legacy.expcore.roles")
local config = require("modules.exp_legacy.config.gui.autofill")
local FlyingText = require("modules/exp_util/flying_text")

local min = math.min
local string_format = string.format

--- @class ExpGui_Autofill.elements
local Elements = {}

--- Format a type and name to a rich text image
--- @param type string
--- @param name string
--- @return string
local function rich_img(type, name)
    return string_format("[img=%s/%s]", type, name)
end

--- Toggle the visible state of a section
--- @class ExpGui_Autofill.elements.toggle_section_button: ExpElement
--- @field data table<LuaGuiElement, LuaGuiElement>
--- @overload fun(parent: LuaGuiElement, section: LuaGuiElement): LuaGuiElement
Elements.toggle_section_button = Gui.define("autofill/toggle_section_button")
    :draw{
        type = "sprite-button",
        sprite = "utility/expand",
        tooltip = { "exp-gui_autofill.tooltip-toggle-section-expand" },
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
        --- @cast def ExpGui_Autofill.elements.toggle_section_button
        local section = def.data[element]
        if Gui.toggle_visible_state(section) then
            element.sprite = "utility/collapse"
            element.tooltip = { "exp-gui_autofill.tooltip-toggle-section-collapse" }
        else
            element.sprite = "utility/expand"
            element.tooltip = { "exp-gui_autofill.tooltip-toggle-section-expand" }
        end
    end) --[[ @as any ]]

--- Toggle if an entity will be autofilled when played
--- @class ExpGui_Autofill.elements.toggle_entity_button: ExpElement
--- @field data table<LuaGuiElement, ExpGui_Autofill.entity_settings>
--- @overload fun(parent: LuaGuiElement, entity_settings: ExpGui_Autofill.entity_settings): LuaGuiElement
Elements.toggle_entity_button = Gui.define("autofill/toggle_entity_button")
    :draw(function(_, parent, entity_settings)
        --- @cast entity_settings ExpGui_Autofill.entity_settings
        local enabled = entity_settings.enabled
        return parent.add{
            type = "sprite-button",
            tooltip = { "exp-gui_autofill.tooltip-toggle-entity", rich_img("item", entity_settings.entity) },
            sprite = enabled and "utility/confirm_slot" or "utility/close_black",
            style = enabled and "shortcut_bar_button_green" or "shortcut_bar_button_red",
        }
    end)
    :style{
        size = 22,
        padding = -2,
    }
    :element_data(
        Gui.from_argument(1)
    )
    :on_click(function(def, player, element)
        --- @cast def ExpGui_Autofill.elements.toggle_entity_button
        local entity_settings = def.data[element]
        local enabled = not entity_settings.enabled
        entity_settings.enabled = enabled

        -- Update the sprite and style
        element.sprite = enabled and "utility/confirm_slot" or "utility/close_black"
        element.style = enabled and "shortcut_bar_button_green" or "shortcut_bar_button_red"

        -- Correct the button size
        local style = element.style
        style.padding = 0
        style.height = 22
        style.width = 22
    end) --[[ @as any ]]

--- Toggle if an item will be inserted into an entity
--- @class ExpGui_Autofill.elements.toggle_item_button: ExpElement
--- @field data table<LuaGuiElement, ExpGui_Autofill.item_settings>
--- @overload fun(parent: LuaGuiElement, item_settings: ExpGui_Autofill.item_settings): LuaGuiElement
Elements.toggle_item_button = Gui.define("autofill/toggle_item_button")
    :draw(function(_, parent, item_settings)
        --- @cast item_settings ExpGui_Autofill.item_settings
        return parent.add{
            type = "sprite-button",
            sprite = "item/" .. item_settings.name,
            tooltip = { "exp-gui_autofill.tooltip-toggle-item", rich_img("item", item_settings.name), item_settings.category },
            style = item_settings.enabled and "shortcut_bar_button_green" or "shortcut_bar_button_red",
        }
    end)
    :style{
        size = 32,
        right_margin = -3,
        padding = -1,
    }
    :element_data(
        Gui.from_argument(1)
    )
    :on_click(function(def, player, element)
        --- @cast def ExpGui_Autofill.elements.toggle_item_button
        local item_settings = def.data[element]
        local enabled = not item_settings.enabled
        item_settings.enabled = enabled

        -- Update the style
        element.style = enabled and "shortcut_bar_button_green" or "shortcut_bar_button_red"

        -- Correct the button size
        local style = element.style
        style.right_margin = -3
        style.padding = -2
        style.height = 32
        style.width = 32
    end) --[[ @as any ]]

--- The amount of an item to insert
--- @class ExpGui_Autofill.elements.amount_textfield: ExpElement
--- @field data table<LuaGuiElement, ExpGui_Autofill.item_settings>
--- @overload fun(parent: LuaGuiElement, item_settings: ExpGui_Autofill.item_settings): LuaGuiElement
Elements.amount_textfield = Gui.define("autofill/amount_textfield")
    :draw(function(_, parent, item_settings)
        --- @cast item_settings ExpGui_Autofill.item_settings
        return parent.add{
            type = "textfield",
            tooltip = { "exp-gui_autofill.tooltip-amount", item_settings.category },
            text = tostring(item_settings.amount) or "",
            clear_and_focus_on_right_click = true,
            numeric = true,
            allow_decimal = false,
            allow_negative = false,
        }
    end)
    :style{
        horizontally_stretchable = true,
        minimal_width = 40,
        height = 31,
        padding = -2,
    }
    :element_data(
        Gui.from_argument(1)
    )
    :on_text_changed(function(def, player, element, event)
        --- @cast def ExpGui_Autofill.elements.amount_textfield
        local value = tonumber(element.text) or 0
        local clamped = math.clamp(value, 0, 999)
        local item_settings = def.data[element]
        item_settings.amount = clamped
        if clamped ~= value then
            element.text = tostring(clamped)
            player.print{ "exp-gui_autofill.invalid", clamped, rich_img("item", item_settings.name), rich_img("entity", item_settings.entity) }
        end
    end) --[[ @as any ]]

--- A disabled version of the autofill settings used as a filler
Elements.disabled_autofill_setting = Gui.define("autofill/empty_autofill_setting")
    :draw(function(_, parent)
        local toggle_element_style = parent.add{
            type = "sprite-button",
            enabled = false,
        }.style
        toggle_element_style.right_margin = -3
        toggle_element_style.width = 32
        toggle_element_style.height = 32

        local amount_element_style = parent.add{
            type = "textfield",
            enabled = false,
        }.style
        amount_element_style.horizontally_stretchable = true
        amount_element_style.minimal_width = 40
        amount_element_style.height = 31
        amount_element_style.padding = -2

        return Gui.no_return()
    end)

--- Section representing an entity
--- @class ExpGui_Autofill.elements.section: ExpElement
--- @field data table<LuaGuiElement, LuaGuiElement|ExpGui_Autofill.entity_settings>
--- @overload fun(parent: LuaGuiElement, entity_settings: ExpGui_Autofill.entity_settings): LuaGuiElement
Elements.section = Gui.define("autofill/section")
    :draw(function(def, parent, entity_settings)
        --- @cast def ExpGui_Autofill.elements.section
        --- @cast entity_settings ExpGui_Autofill.entity_settings
        local header = Gui.elements.header(parent, {
            caption = { "exp-gui_autofill.caption-section-header", rich_img("item", entity_settings.entity), { "entity-name." .. entity_settings.entity } },
            tooltip = { "exp-gui_autofill.tooltip-toggle-section" },
        })

        local section_table = parent.add{
            type = "table",
            column_count = 3,
            visible = false,
        }

        section_table.style.padding = 3

        local header_label = header.label
        Elements.toggle_entity_button(header, entity_settings)
        def.data[header_label] = Elements.toggle_section_button(header, section_table)
        def.data[section_table] = entity_settings

        def:link_element(header_label)
        return def:unlink_element(section_table)
    end)
    :on_click(function(def, player, element, event)
        --- @cast def ExpGui_Autofill.elements.section
        event.element = def.data[element] --[[ @as LuaGuiElement ]]
        Elements.toggle_section_button:raise_event(event)
    end) --[[ @as any ]]

--- Add an item category to a section, at most three can exist
--- @param section LuaGuiElement
--- @param category_name string
--- @return LuaGuiElement, number
function Elements.section.add_category(section, category_name)
    local category = section.add{
        type = "table",
        column_count = 2,
    }

    category.style.vertical_spacing = 1

    local ctn = 0
    local entity_settings = Elements.section.data[section] --[[ @as ExpGui_Autofill.entity_settings ]]
    for _, item_data in pairs(entity_settings.items) do
        if item_data.category == category_name then
            Elements.toggle_item_button(category, item_data)
            Elements.amount_textfield(category, item_data)
            ctn = ctn + 1
        end
    end

    return category, ctn
end

--- @class ExpGui_Autofill.item_settings
--- @field entity string
--- @field category string
--- @field inv defines.inventory
--- @field name string
--- @field amount number
--- @field enabled boolean

--- @class ExpGui_Autofill.entity_settings
--- @field entity string
--- @field enabled boolean
--- @field items ExpGui_Autofill.item_settings[]

--- Container added to the left gui flow
--- @class ExpGui_Autofill.elements.container: ExpElement
--- @field data table<string, ExpGui_Autofill.entity_settings>
Elements.container = Gui.define("autofill/container")
    :draw(function(def, parent)
        --- @cast def ExpGui_Autofill.elements.container
        local container = Gui.elements.container(parent)
        local scroll_pane = Gui.elements.scroll_pane(container, 524)
        scroll_pane.style.padding = 0

        -- Cant modify vertical spacing on scroll pane style so need a sub flow
        scroll_pane = scroll_pane.add{ type = "flow", direction = "vertical" }
        scroll_pane.style.vertical_spacing = 0
        scroll_pane.style.padding = 0

        -- Add a header
        Gui.elements.header(scroll_pane, {
            caption = { "exp-gui_autofill.caption-main" },
        })

        -- Setup the player data, this is used by section and item category so needs to be done here
        local player = Gui.get_player(parent)
        --- @type table<string, ExpGui_Autofill.entity_settings>
        local player_data = def.data[player] or table.deep_copy(config.default_entities)
        def.data[player] = player_data

        -- Add sections for each entity
        for _, entity_settings in pairs(player_data) do
            local section = Elements.section(scroll_pane, entity_settings)

            -- Add the categories
            local categories, largest = {}, 0
            for _, category_name in pairs(config.categories) do
                local category, size = Elements.section.add_category(section, category_name)
                if largest < size then
                    largest = size
                end
                categories[category] = size
            end

            -- Fill in blanks for smaller categories
            for category, size in pairs(categories) do
                for i = size, largest - 1 do
                    Elements.disabled_autofill_setting(category)
                end
            end
        end

        return container.parent
    end) --[[ @as any ]]

--- Get the autofill settings for a player
--- @param player LuaPlayer
--- @param entity_name string
--- @return ExpGui_Autofill.entity_settings
function Elements.container.get_autofill_settings(player, entity_name)
    return Elements.container.data[player][entity_name]
end

--- Add the element to the left flow with a toolbar button
Gui.add_left_element(Elements.container, false)
Gui.toolbar.create_button{
    name = "toggle_autofill",
    left_element = Elements.container,
    sprite = config.icon,
    tooltip = { "exp-gui_autofill.tooltip-main" },
    visible = function(player, element)
        return Roles.player_allowed(player, "gui/autofill")
    end
}

--- @param event EventData.on_built_entity
local function on_built_entity(event)
    local player = Gui.get_player(event)

    -- Check if the entity is in the config and enabled
    local entity = event.entity
    local entity_settings = Elements.container.get_autofill_settings(player, entity.name)
    if not entity_settings or not entity_settings.enabled then
        return
    end

    -- Get the inventory of the player
    local player_inventory = player.get_main_inventory() --- @cast player_inventory -nil
    local player_get_item_count = player_inventory.get_item_count
    local player_remove = player_inventory.remove

    -- Setup the tables being used
    local offset = { x = 0, y = 0 }
    local item = { name = "", count = 0 }
    local color = { r = 0, g = 255, b = 0, a = 255 }
    local flyingText = {
        target_entity = entity,
        text = "",
        offset = offset,
        player = player,
        color = color,
    }

    for _, item_settings in pairs(entity_settings.items) do
        -- Check if the item is enabled or goto next item
        if not item_settings.enabled then goto continue end

        -- Get the inventory of the entity or goto next item
        local entity_inventory = entity.get_inventory(item_settings.inv)
        if not entity_inventory then goto continue end

        local preferred_amount = item_settings.amount
        local item_amount = player_get_item_count(item_settings.name)
        if item_amount ~= 0 then
            item.name = item_settings.name
            item.count = min(preferred_amount, item_amount)
            if not entity_inventory.can_insert(item) then goto continue end
            local inserted = entity_inventory.insert(item)

            local ran_out = item_amount < preferred_amount
            color.r = ran_out and 255 or 0
            color.g = ran_out and 165 or 255

            item.count = inserted
            player_remove(item)

            flyingText.text = { "exp-gui_autofill.inserted", inserted, rich_img("item", item_settings.name), rich_img("entity", entity.name) }
            FlyingText.create_above_entity(flyingText)
            offset.y = offset.y - 0.33
        end

        ::continue::
    end
end

local e = defines.events

return {
    elements = Elements,
    events = {
        [e.on_built_entity] = on_built_entity,
    }
}
