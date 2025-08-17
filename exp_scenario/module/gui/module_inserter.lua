--[[-- Gui - Module Inserter
Adds a Gui which creates an selection planner to insert modules into buildings
]]

local Gui = require("modules/exp_gui")
local AABB = require("modules/exp_util/aabb")
local Roles = require("modules/exp_legacy/expcore/roles")
local Selection = require("modules/exp_legacy/modules/control/selection")
local SelectionModuleArea = "ModuleArea"

local config = require("modules/exp_legacy/config/module")

--- @class ExpGui_ModuleInserter.elements
local Elements = {}

--- Load all the valid machines from the config file
local machine_names = {}
for mod_name, machine_set in pairs(config.machine_sets) do
    if script.active_mods[mod_name] then
        for machine_name, v in pairs(machine_set) do
            config.machines[machine_name] = v
            table.insert(machine_names, machine_name)
        end
    end
end

--- Load all the modules which provide productivity bonus
local prod_module_names = {}
for name, item in pairs(prototypes.item) do
    if item.module_effects and item.module_effects.productivity and item.module_effects.productivity > 0 then
        prod_module_names[#prod_module_names + 1] = name
    end
end

--- Filters used for the different elem buttons
local elem_filter = {
    -- Select only valid machines
    machine_name = { {
        filter = "name",
        name = machine_names,
    } },
    -- Select modules that don't give productivity
    no_prod = { {
        filter = "type",
        type = "module",
    }, {
        filter = "name",
        name = prod_module_names,
        mode = "and",
        invert = true,
    } },
    -- Select any modules
    with_prod = { {
        filter = "type",
        type = "module",
    } },
}

--- Button used to create a selection planner from a module table
--- @class ExpGui_ModuleInserter.elements.create_selection_planner: ExpElement
--- @field data table<LuaGuiElement, LuaGuiElement>
--- @overload fun(parent: LuaGuiElement, module_table: LuaGuiElement): LuaGuiElement
Elements.create_selection_planner = Gui.element("module_inserter/create_selection_planner")
    :draw{
        type = "sprite-button",
        sprite = "item/upgrade-planner",
        tooltip = { "exp-gui_module-inserter.tooltip-apply" },
        style = "shortcut_bar_button",
    }
    :style{
        size = 28,
        padding = 0,
    }
    :element_data(Gui.property_from_arg(1))
    :on_click(function(def, player, element)
        --- @cast def ExpGui_ModuleInserter.elements.create_selection_planner
        Selection.start(player, SelectionModuleArea, false, def.data[element])
    end) --[[ @as any ]]

--- Used to select the machine to apply modules to
--- @class ExpGui_ModuleInserter.elements.machine_selector: ExpElement
--- @field data table<LuaGuiElement, { on_last_row: boolean, row_separators: LuaGuiElement[], module_selectors: LuaGuiElement[] }>
--- @overload fun(parent: LuaGuiElement, row_separators: LuaGuiElement[], module_selectors: LuaGuiElement[]): LuaGuiElement
Elements.machine_selector = Gui.element("module_inserter/machine_selector")
    :draw{
        type = "choose-elem-button",
        elem_type = "entity",
        elem_filters = elem_filter.machine_name,
        style = "slot_button",
    }
    :element_data{
        on_last_row = true,
        row_separators = Gui.property_from_arg(1),
        module_selectors = Gui.property_from_arg(2),
    }
    :on_elem_changed(function(def, player, element, event)
        --- @cast def ExpGui_ModuleInserter.elements.machine_selector
        local element_data = def.data[element]
        local machine_name = element.elem_value --[[ @as string? ]]
        if not machine_name then
            -- No machine selected
            if not element_data.on_last_row then
                -- Not the last row so delete it
                Elements.module_table._on_remove_row(element)
                Gui.destroy_if_valid(element)
                for _, separator in pairs(element_data.row_separators) do
                    Gui.destroy_if_valid(separator)
                end
                for _, selector in pairs(element_data.module_selectors) do
                    Gui.destroy_if_valid(selector)
                end
                return
            end
            -- Reset to default state, all disabled with only first row visible
            for _, separator in pairs(element_data.row_separators) do
                separator.visible = false
            end
            for i, selector in pairs(element_data.module_selectors) do
                selector.visible = i <= config.module_slots_per_row
                selector.enabled = false
                selector.elem_value = nil
            end
            return
        end

        -- Machine selected, update the number of enabled and visible module selectors
        local active_to = prototypes.entity[machine_name].module_inventory_size
        local row_count = math.ceil(active_to / config.module_slots_per_row)
        local visible_to = row_count * config.module_slots_per_row
        for i, separator in pairs(element_data.row_separators) do
            separator.visible = i < row_count
        end
        for i, selector in pairs(element_data.module_selectors) do
            if i <= active_to then
                if config.machines[machine_name].prod then
                    selector.elem_filters = elem_filter.with_prod
                else
                    selector.elem_filters = elem_filter.no_prod
                end

                selector.visible = true
                selector.enabled = true
                selector.elem_value = { name = config.machines[machine_name].module }
            else
                selector.visible = i <= visible_to
                selector.enabled = false
                selector.elem_value = nil
            end
        end

        -- Add a new row to the table
        element_data.on_last_row = false
        Elements.module_table.add_row(element.parent)
    end) --[[ @as any ]]

--- Used to select the modules to be applied
Elements.module_selector = Gui.element("module_inserter/module_selector")
    :draw{
        type = "choose-elem-button",
        elem_type = "item-with-quality",
        elem_filters = elem_filter.no_prod,
        visible = Gui.property_from_arg(1),
        enabled = false,
        style = "slot_button",
    }

--- A table that allows selecting modules 
--- @class ExpGui_ModuleInserter.elements.module_table: ExpElement
--- @field data table<LuaGuiElement, LuaGuiElement[]>
Elements.module_table = Gui.element("module_inserter/module_table")
    :draw(function(def, parent)
        --- @cast def ExpGui_ModuleInserter.elements.module_table
        local slots_per_row = config.module_slots_per_row + 1
        return Gui.elements.scroll_table(parent, 280, slots_per_row)
    end)
    :element_data{} --[[ @as any ]]

--- Add a row to a module table
--- @param module_table LuaGuiElement
function Elements.module_table.add_row(module_table)
    local row_separators, module_selectors = {}, {}
    local rows = Elements.module_table.data[module_table]
    rows[#rows + 1] = Elements.machine_selector(module_table, row_separators, module_selectors)

    -- Add the module selectors and row separators
    local slots_per_row = config.module_slots_per_row + 1
    for i = 1, config.module_slot_max do
        if i % slots_per_row == 0 then
            row_separators[#row_separators + 1] = module_table.add{ type = "flow", visible = false }
        end
        module_selectors[i] = Elements.module_selector(module_table, i <= config.module_slots_per_row)
    end
end

--- Clean-up the data associated with a row
--- @param machine_selector LuaGuiElement
function Elements.module_table._on_remove_row(machine_selector)
    table.remove_element(Elements.module_table.data[machine_selector.parent], machine_selector)
end

--- Container added to the left gui flow
Elements.container = Gui.element("module_inserter/container")
    :draw(function(def, parent)
        local container = Gui.elements.container(parent)
        local header = Gui.elements.header(container, { caption = { "exp-gui_module-inserter.caption-main" } })
        local module_table = Elements.module_table(container)
        Elements.module_table.add_row(module_table)
        Elements.create_selection_planner(header, module_table)
        return container.parent
    end)

--- Add the element to the left flow with a toolbar button
Gui.add_left_element(Elements.container, false)
Gui.toolbar.create_button{
    name = "toggle_module_inserter",
    left_element = Elements.container,
    sprite = "item/productivity-module-3",
    tooltip = { "exp-gui_module-inserter.tooltip-main" },
    visible = function(player, element)
        return Roles.player_allowed(player, "gui/module")
    end
}

--- Apply module changes to a crafting machine
--- @param player LuaPlayer
--- @param area BoundingBox
--- @param machine_name string
--- @param planner_with_prod LuaItemStack
--- @param planner_no_prod LuaItemStack
local function apply_planners_in_area(player, area, machine_name, planner_with_prod, planner_no_prod)
    local force = player.force
    local surface = player.surface
    local upgrade_area = surface.upgrade_area

    -- Bounding box table to be reused in the loop below
    --- @type BoundingBox
    local param_area = {
        left_top = {},
        right_bottom = {}
    }

    -- Update area param table to be reused in the loop below
    --- @type LuaSurface.upgrade_area_param
    local params = {
        area = param_area,
        item = planner_with_prod,
        player = player,
        force = force,
    }

    -- Find all required entities in the area and apply the correct module planner to them
    for _, entity in pairs(surface.find_entities_filtered{ area = area, name = machine_name, force = force }) do
        local pos = entity.position
        param_area.left_top = pos
        param_area.right_bottom = pos

        local m_current_recipe = entity.get_recipe()
        local r_proto = m_current_recipe and m_current_recipe.prototype

        if r_proto and r_proto.allowed_effects and r_proto.allowed_effects["productivity"] then
            params.item = planner_with_prod
            upgrade_area(params)
        else
            params.item = planner_no_prod
            upgrade_area(params)
        end
    end
end

--- When an area is selected to have module changes applied to it
--- @param event EventData.on_player_selected_area
--- @param module_table LuaGuiElement
Selection.on_selection(SelectionModuleArea, function(event, module_table)
    local player = assert(game.get_player(event.player_index))
    local area = AABB.expand(event.area)

    -- Create an inventory with three upgrade planners
    local inventory = game.create_inventory(3)
    inventory.insert{ name = "upgrade-planner", count = 3 }
    local bulk_mapper_index = 1
    local planner_bulk = inventory[1]
    local planner_with_prod = inventory[2]
    local planner_no_prod = inventory[3]

    -- Create a table to be reused when setting mappers
    local mapper_table = {
        type = "entity",
        name = "",
        module_slots = {},
        quality = "",
        comparator = "=",
    }

    for _, machine_selector in pairs(Elements.module_table.data[module_table]) do
        local machine_name = machine_selector.elem_value --[[ @as string? ]]
        if not machine_name then
            goto continue
        end

        local module_selectors = Elements.machine_selector.data[machine_selector].module_selectors
        local entity_prototype = prototypes.entity[machine_name]
        local wants_prod_modules = false
        local module_index = 1
        local all_modules = {}
        local no_prod = {}

        -- Get all the modules selected
        for i = 1, entity_prototype.module_inventory_size do
            local module_selector = module_selectors[i]
            local module = module_selector.elem_value --[[ @as { name: string, quality: string }? ]]
            if module then
                -- Module selected, add it the module arrays
                local no_prod_name = module.name:gsub("productivity", "efficiency")
                wants_prod_modules = wants_prod_modules or module.name ~= no_prod_name
                no_prod[module_index] = { name = no_prod_name, quality = module.quality }
                all_modules[module_index] = module
                module_index = module_index + 1
            else
                -- No module selected, insert blanks
                no_prod[module_index] = {}
                all_modules[module_index] = {}
                module_index = module_index + 1
            end
        end

        if wants_prod_modules and entity_prototype.get_crafting_speed() then
            -- Crafting machines wanting prod modules must be handled on a case by case biases
            local i = 0
            mapper_table.name = machine_name
            for quality_name in pairs(prototypes.quality) do
                i = i + 1
                mapper_table.module_slots = nil
                mapper_table.quality = quality_name
                planner_with_prod.set_mapper(i, "from", mapper_table)
                planner_no_prod.set_mapper(i, "from", mapper_table)
                mapper_table.module_slots = all_modules
                planner_with_prod.set_mapper(i, "to", mapper_table)
                mapper_table.module_slots = no_prod
                planner_no_prod.set_mapper(i, "to", mapper_table)
            end
            apply_planners_in_area(player, area, machine_name, planner_with_prod, planner_no_prod)
        else
            -- All other machines can be applied in a single upgrade planner
            mapper_table.name = machine_name
            for quality_name in pairs(prototypes.quality) do
                mapper_table.module_slots = nil
                mapper_table.quality = quality_name
                planner_bulk.set_mapper(bulk_mapper_index, "from", mapper_table)
                mapper_table.module_slots = all_modules
                planner_bulk.set_mapper(bulk_mapper_index, "to", mapper_table)
                bulk_mapper_index = bulk_mapper_index + 1
            end
        end

        ::continue::
    end

    -- Apply remaining module changes using the bulk planner
    if bulk_mapper_index > 1 then
        player.surface.upgrade_area{
            area = area,
            item = planner_bulk,
            force = player.force,
            player = player,
        }
    end

    inventory.destroy()
end)

--- Apply rotation and modules to machines after their settings are pasted
--- @param event EventData.on_entity_settings_pasted
local function on_entity_settings_pasted(event)
    local source = event.source
    if not source or not source.valid then
        return
    end

    local destination = event.destination
    if not destination or not destination.valid then
        return
    end

    if config.copy_paste_rotation then
        -- Attempt to rotate a machine to match the source machine
        if (source.name == destination.name or source.prototype.fast_replaceable_group == destination.prototype.fast_replaceable_group) then
            if source.supports_direction and destination.supports_direction and source.type ~= "transport-belt" then
                local destination_box = destination.bounding_box

                local ltx = destination_box.left_top.x
                local lty = destination_box.left_top.y
                local rbx = destination_box.right_bottom.x
                local rby = destination_box.right_bottom.y

                local old_direction = destination.direction
                destination.direction = source.direction

                if ltx ~= destination_box.left_top.x or lty ~= destination_box.left_top.y
                or rbx ~= destination_box.right_bottom.x or rby ~= destination_box.right_bottom.y then
                    destination.direction = old_direction
                end
            end
        end
    end

    if config.copy_paste_module then
        -- Attempt to copy the modules from the source machine
        if source.name ~= destination.name then
            goto end_copy_paste_module
        end

        local module_inventory = source.get_module_inventory()
        if not module_inventory then
            goto end_copy_paste_module
        end

        -- Get the modules and add them to the planner
        local all_modules = {}
        for i = 1, #module_inventory do
            local slot = module_inventory[i]
            if slot.valid_for_read and slot.count > 0 then
                all_modules[i] = { name = slot.name, quality = slot.quality.name }
            else
                all_modules[i] = {}
            end
        end

        -- Create an inventory with an upgrade planner
        local inventory = game.create_inventory(1)
        inventory.insert{ name = "upgrade-planner", count = 3 }

        -- Set the mapping for the planner
        local planner = inventory[1]
        local mapper = {
            type = "entity",
            name = destination.name,
            quality = destination.quality.name,
            comparator = "=",
        }
        planner.set_mapper(1, "from", mapper)
        mapper.module_slots = all_modules
        planner.set_mapper(1, "to", mapper)

        -- Apply the planner
        local player = assert(game.get_player(event.player_index))
        player.surface.upgrade_area{
            area = destination.bounding_box,
            item = planner,
            player = player,
            force = player.force,
        }

        inventory.destroy()
        ::end_copy_paste_module::
    end
end

local e = defines.events

return {
    elements = Elements,
    events = {
        [e.on_entity_settings_pasted] = on_entity_settings_pasted,
    }
}
