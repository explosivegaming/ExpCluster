---- module inserter
-- @gui Module

local Gui = require("modules/exp_gui")
local AABB = require("modules/exp_util/aabb")
local Event = require("modules/exp_legacy/utils/event") --- @dep utils.event
local Roles = require("modules.exp_legacy.expcore.roles") --- @dep expcore.roles
local config = require("modules.exp_legacy.config.module") --- @dep config.module
local Selection = require("modules.exp_legacy.modules.control.selection") --- @dep modules.control.selection
local SelectionModuleArea = "ModuleArea"

local module_container -- Container for this GUI

local machine_names = {}
for mod_name, machine_set in pairs(config.machine_set) do
    if script.active_mods[mod_name] then
        for machine_name, v in pairs(machine_set) do
            config.machine[machine_name] = v
            table.insert(machine_names, machine_name)
        end
    end
end

local prod_module_names = {}
for name, item in pairs(prototypes.item) do
    if item.module_effects and item.module_effects.productivity and item.module_effects.productivity > 0 then
        prod_module_names[#prod_module_names + 1] = name
    end
end

local elem_filter = {
    machine_name = { {
        filter = "name",
        name = machine_names,
    } },
    no_prod = { {
        filter = "type",
        type = "module",
    }, {
        filter = "name",
        name = prod_module_names,
        mode = "and",
        invert = true,
    } },
    with_prod = { {
        filter = "type",
        type = "module",
    } },
}

--- Apply module changes to a crafting machine
--- @param player LuaPlayer
--- @param area BoundingBox
--- @param machine_name string
--- @param planner_with_prod LuaItemStack
--- @param planner_no_prod LuaItemStack
local function apply_module_to_crafter(player, area, machine_name, planner_with_prod, planner_no_prod)
    local force = player.force
    local surface = player.surface
    local upgrade_area = surface.upgrade_area

    --- @type BoundingBox
    local param_area = { left_top = {}, right_bottom = {} }

    --- @type LuaSurface.upgrade_area_param
    local params = {
        area = param_area,
        item = planner_with_prod,
        player = player,
        force = force,
    }

    for _, entity in pairs(surface.find_entities_filtered{ area = area, name = machine_name, force = force }) do
        local pos = entity.position
        param_area.left_top = pos
        param_area.right_bottom = pos

        local m_current_recipe = entity.get_recipe()
        local r_proto = m_current_recipe and m_current_recipe.prototype

        if r_proto and (r_proto.maximum_productivity or (r_proto.allowed_effects and r_proto.allowed_effects["productivity"])) then
            params.item = planner_with_prod
            upgrade_area(params)
        else
            params.item = planner_no_prod
            upgrade_area(params)
        end
    end
end

--- when an area is selected to add protection to the area
--- @param event EventData.on_player_selected_area
Selection.on_selection(SelectionModuleArea, function(event)
    local area = AABB.expand(event.area)
    local player = game.players[event.player_index]
    local container = Gui.get_left_element(module_container, player)
    local scroll_table = container.frame.scroll.table

    -- Create an inventory with three upgrade planners
    local inventory = game.create_inventory(3)
    inventory.insert{ name = "upgrade-planner", count = 3 }
    local planner_all = inventory[1]
    local planner_with_prod = inventory[2]
    local planner_no_prod = inventory[3]
    local mapper_index = 1

    for row = 1, config.default_module_row_count do
        local machine_name = scroll_table["module_mm_" .. row .. "_0"].elem_value --[[@as string]]
        local entity_proto = prototypes.entity[machine_name]

        if machine_name then
            local is_prod_crafter = false
            local module_index = 1
            local modules = {}
            local no_prod = {}

            -- Add all the modules selected
            for column = 1, entity_proto.module_inventory_size do
                local module_name = scroll_table["module_mm_" .. row .. "_" .. column].elem_value --[[ @as {name:string, quality:string} ]]

                if module_name then
                    local not_prod = module_name.name:gsub("productivity", "efficiency")
                    modules[module_index] = module_name
                    no_prod[module_index] = { name = not_prod, quality = module_name.quality }
                    module_index = module_index + 1
                    if not is_prod_crafter and module_name ~= not_prod and entity_proto.get_crafting_speed() then
                        is_prod_crafter = true
                    end
                else
                    modules[module_index] = {}
                    no_prod[module_index] = {}
                    module_index = module_index + 1
                end
            end

            if is_prod_crafter then
                -- Crafting machines with prod need to be handled on a case by case biases
                local i = 0
                for quality_name in pairs(prototypes.quality) do
                    i = i + 1
                    planner_with_prod.set_mapper(i, "from", {
                        type = "entity",
                        name = machine_name,
                        quality = quality_name,
                        comparator = "=",
                    })
                    planner_no_prod.set_mapper(i, "from", {
                        type = "entity",
                        name = machine_name,
                        quality = quality_name,
                        comparator = "=",
                    })
                    planner_with_prod.set_mapper(i, "to", {
                        type = "entity",
                        name = machine_name,
                        module_slots = modules,
                        quality = quality_name,
                        comparator = "=",
                    })
                    planner_no_prod.set_mapper(i, "to", {
                        type = "entity",
                        name = machine_name,
                        module_slots = no_prod,
                        quality = quality_name,
                        comparator = "=",
                    })
                end
                apply_module_to_crafter(player, area, machine_name, planner_with_prod, planner_no_prod)
            else
                -- All other machines can be applied in a single upgrade planner
                for quality_name in pairs(prototypes.quality) do
                    planner_all.set_mapper(mapper_index, "from", {
                        type = "entity",
                        name = machine_name,
                        quality = quality_name,
                        comparator = "=",
                    })
                    planner_all.set_mapper(mapper_index, "to", {
                        type = "entity",
                        name = machine_name,
                        module_slots = modules,
                        quality = quality_name,
                        comparator = "=",
                    })
                    mapper_index = mapper_index + 1
                end
            end
        end
    end

    -- Apply module changes for non crafting (or without prod selected)
    if mapper_index > 1 then
        player.surface.upgrade_area{
            area = area,
            item = planner_all,
            force = player.force,
            player = player,
        }
    end

    inventory.destroy()
end)

--- Set the state of all elem selectors on a row
--- @param player LuaPlayer
--- @param element_name string
local function row_set(player, element_name)
    local container = Gui.get_left_element(module_container, player)
    local scroll_table = container.frame.scroll.table
    local machine_name = scroll_table[element_name .. "0"].elem_value --[[ @as string ]]

    if machine_name then
        local active_to = prototypes.entity[machine_name].module_inventory_size
        local row_count = math.ceil(active_to / config.module_slots_per_row)
        local visible_to = row_count * config.module_slots_per_row
        for i = 1, config.module_slot_max do
            local element = scroll_table[element_name .. i]
            if i <= active_to then
                if config.machine[machine_name].prod then
                    element.elem_filters = elem_filter.with_prod
                else
                    element.elem_filters = elem_filter.no_prod
                end

                element.visible = true
                element.enabled = true
                element.elem_value = { name = config.machine[machine_name].module }
            else
                element.visible = i <= visible_to
                element.enabled = false
                element.elem_value = nil
            end
            if i % (config.module_slots_per_row + 1) == 0 then
                scroll_table[element_name .. "pad" .. i].visible = element.visible
            end
        end
    else
        for i = 1, config.module_slot_max do
            local element = scroll_table[element_name .. i]
            element.visible = i <= config.module_slots_per_row
            element.enabled = false
            element.elem_value = nil
            if i % (config.module_slots_per_row + 1) == 0 then
                scroll_table[element_name .. "pad" .. i].visible = false
            end
        end
    end
end

local button_apply = Gui.element("button_apply")
    :draw{
        type = "button",
        caption = { "module.apply" },
        style = "button",
    }:on_click(function(def, player, element)
        if Selection.is_selecting(player, SelectionModuleArea) then
            Selection.stop(player)
        else
            Selection.start(player, SelectionModuleArea)
        end
    end)

module_container = Gui.element("module_container")
    :draw(function(definition, parent)
        local container = Gui.elements.container(parent, (config.module_slots_per_row + 2) * 36)
        Gui.elements.header(container, {
            caption = "Module Inserter",
        })

        local slots_per_row = config.module_slots_per_row + 1
        local scroll_table = Gui.elements.scroll_table(container, (config.module_slots_per_row + 2) * 36, slots_per_row, "scroll")

        for i = 1, config.default_module_row_count do
            scroll_table.add{
                name = "module_mm_" .. i .. "_0",
                type = "choose-elem-button",
                elem_type = "entity",
                elem_filters = elem_filter.machine_name,
                style = "slot_button",
            }

            for j = 1, config.module_slot_max do
                if j % slots_per_row == 0 then
                    scroll_table.add{
                        type = "flow",
                        name = "module_mm_" .. i .. "_pad" .. j,
                        visible = false,
                    }
                end
                scroll_table.add{
                    name = "module_mm_" .. i .. "_" .. j,
                    type = "choose-elem-button",
                    elem_type = "item-with-quality",
                    elem_filters = elem_filter.no_prod,
                    style = "slot_button",
                    enabled = false,
                    visible = j <= config.module_slots_per_row,
                }
            end
        end

        button_apply(container)

        return container.parent
    end)

--- Add the element to the left flow with a toolbar button
Gui.add_left_element(module_container, false)
Gui.toolbar.create_button{
    name = "module_toggle",
    left_element = module_container,
    sprite = "item/productivity-module-3",
    tooltip = { "module.main-tooltip" },
    visible = function(player, element)
        return Roles.player_allowed(player, "gui/module")
    end
}

--- @param event EventData.on_gui_elem_changed
Event.add(defines.events.on_gui_elem_changed, function(event)
    if event.element.name:sub(1, 10) == "module_mm_" then
        if event.element.name:sub(-1) == "0" then
            row_set(game.players[event.player_index], "module_mm_" .. event.element.name:sub(-3):sub(1, 1) .. "_")
        end
    end
end)

--- @param event EventData.on_entity_settings_pasted
Event.add(defines.events.on_entity_settings_pasted, function(event)
    local source = event.source
    local destination = event.destination
    local player = game.players[event.player_index]

    if not player then
        return
    end

    if not source or not source.valid then
        return
    end

    if not destination or not destination.valid then
        return
    end

    -- rotate machine also
    if config.copy_paste_rotation then
        if (source.name == destination.name or source.prototype.fast_replaceable_group == destination.prototype.fast_replaceable_group) then
            if source.supports_direction and destination.supports_direction and source.type ~= "transport-belt" then
                local destination_box = destination.bounding_box

                local ltx = destination_box.left_top.x
                local lty = destination_box.left_top.y
                local rbx = destination_box.right_bottom.x
                local rby = destination_box.right_bottom.y

                local old_direction = destination.direction
                destination.direction = source.direction

                if ltx ~= destination_box.left_top.x or lty ~= destination_box.left_top.y or rbx ~= destination_box.right_bottom.x or rby ~= destination_box.right_bottom.y then
                    destination.direction = old_direction
                end
            end
        end
    end

    --[[
    TODO handle later as may need using global to reduce creation of upgrade plans

    if config.copy_paste_module then
        if source.name ~= destination.name then
            return
        end

        local source_inventory = source.get_module_inventory()

        if not source_inventory then
            return
        end

        local source_inventory_content = source_inventory.get_contents()

        if not source_inventory_content then
            return
        end

        clear_module(player, destination.bounding_box, destination.name)

        if next(source_inventory_content) ~= nil then
            apply_module(player, destination.bounding_box, destination.name, { ["n"] = source_inventory_content, ["p"] = source_inventory_content })
        end
    end
    ]]
end)
