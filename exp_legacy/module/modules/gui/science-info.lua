--[[-- Gui Module - Science Info
    - Adds a science info gui that shows production usage and net for the different science packs as well as an eta
    @gui Science-Info
    @alias science_info
]]

local ExpUtil = require("modules/exp_util")
local Gui = require("modules/exp_gui")
local Roles = require("modules.exp_legacy.expcore.roles")
local Event = require("modules/exp_legacy/utils/event") --- @dep utils.event
local config = require("modules.exp_legacy.config.gui.science") --- @dep config.gui.science
local Production = require("modules.exp_legacy.modules.control.production") --- @dep modules.control.production

local clock_time_format = ExpUtil.format_time_factory_locale{ format = "clock", hours = true, minutes = true, seconds = true }
local long_time_format = ExpUtil.format_time_factory_locale{ format = "long", hours = true, minutes = true, seconds = true }

local null_time_clock = { "science-info.eta-time", clock_time_format(nil) }
local null_time_long = long_time_format(nil)

--- Remove invalid science packs, this can result from a certain mod not being loaded
for i = #config, 1, -1 do
    if not prototypes.item[config[i]] then
        table.remove(config, i)
    end
end

--- Data label that contains the value and the suffix
-- @element production_label
local production_label = Gui.element("science_info_production_label")
    :draw(function(_, parent, production_label_data)
        local name = production_label_data.name
        local tooltip = production_label_data.tooltip
        local color = production_label_data.color

        -- Add an alignment for the number
        local alignment = Gui.elements.aligned_flow(parent, { name = name })

        -- Add the main value label
        local element =
            alignment.add{
                name = "label",
                type = "label",
                caption = production_label_data.caption,
                tooltip = tooltip,
            }

        -- Change the style
        element.style.font_color = color

        -- Add the suffix label
        local suffix_element =
            parent.add{
                name = "suffix-" .. name,
                type = "label",
                caption = { "science-info.unit", production_label_data.suffix },
                tooltip = tooltip,
            }

        -- Change the style
        local suffix_element_style = suffix_element.style
        suffix_element_style.font_color = color
        suffix_element_style.right_margin = 1

        -- Return the value label
        return element
    end)

-- Get the data that is used with the production label
local function get_production_label_data(name, tooltip, value, cutout, secondary)
    local data_colour = Production.get_color(config.color_cutoff * cutout, value, secondary)
    local suffix, caption = Production.format_number(value)

    return {
        name = name,
        caption = caption,
        suffix = suffix,
        tooltip = tooltip,
        color = data_colour,
    }
end

-- Updates a prodution label to match the current data
local function update_production_label(parent, production_label_data)
    local name = production_label_data.name
    local tooltip = production_label_data.tooltip
    local color = production_label_data.color

    -- Update the production label
    local production_label_element = parent[name] and parent[name].label or production_label(parent, production_label_data)
    production_label_element.caption = production_label_data.caption
    production_label_element.tooltip = production_label_data.tooltip
    production_label_element.style.font_color = color

    -- Update the suffix label
    local suffix_element = parent["suffix-" .. name]
    suffix_element.caption = { "science-info.unit", production_label_data.suffix }
    suffix_element.tooltip = tooltip
    suffix_element.style.font_color = color
end

--- Adds 4 elements that show the data for a science pack
-- @element science_pack_base
local science_pack_base = Gui.element("science_info_science_pack_base")
    :draw(function(_, parent, science_pack_data)
        local science_pack = science_pack_data.science_pack

        -- Draw the icon for the science pack
        local icon_style = science_pack_data.icon_style
        local pack_icon =
            parent.add{
                name = "icon-" .. science_pack,
                type = "sprite-button",
                sprite = "item/" .. science_pack,
                tooltip = { "item-name." .. science_pack },
                style = icon_style,
            }

        -- Change the style of the icon
        local pack_icon_style = pack_icon.style
        pack_icon.ignored_by_interaction = true
        pack_icon_style.height = 55
        if icon_style == "slot_button" then
            pack_icon_style.padding = { 0, -2 }
            pack_icon_style.width = 36
        end

        -- Draw the delta flow
        local delta_flow =
            parent.add{
                name = "delta-" .. science_pack,
                type = "frame",
                style = "bordered_frame",
            }
        delta_flow.style.padding = { 0, 3 }

        -- Draw the delta flow table
        local delta_table =
            delta_flow.add{
                name = "table",
                type = "table",
                column_count = 2,
            }
        delta_table.style.padding = 0

        -- Draw the production labels
        update_production_label(delta_table, science_pack_data.positive)
        update_production_label(delta_table, science_pack_data.negative)
        update_production_label(parent, science_pack_data.net)

        -- Return the pack icon
        return pack_icon
    end)

local function get_science_pack_data(player, science_pack)
    local force = player.force

    -- Check that some packs have been made
    local total = Production.get_production_total(force, science_pack)
    if total.made == 0 then return end
    local minute = Production.get_production(force, science_pack, defines.flow_precision_index.one_minute)
    local hour = Production.get_production(force, science_pack, defines.flow_precision_index.one_hour)

    -- Get the icon style
    local icon_style = "slot_button"
    local flux = Production.get_fluctuations(force, science_pack, defines.flow_precision_index.one_minute)
    if minute.net > 0 and flux.net > -config.color_flux / 2 then
        icon_style = "slot_sized_button_green"
    elseif flux.net < -config.color_flux then
        icon_style = "slot_sized_button_red"
    elseif minute.made > 0 then
        icon_style = "yellow_slot_button"
    end

    -- Return the pack data
    return {
        science_pack = science_pack,
        icon_style = icon_style,
        positive = get_production_label_data(
            "pos-" .. science_pack,
            { "science-info.pos-tooltip", total.made },
            minute.made, hour.made
        ),
        negative = get_production_label_data(
            "neg-" .. science_pack,
            { "science-info.neg-tooltip", total.used },
            -minute.used, hour.used
        ),
        net = get_production_label_data(
            "net-" .. science_pack,
            { "science-info.net-tooltip", total.net },
            minute.net, minute.net > 0 and hour.net or 0,
            minute.made + minute.used
        ),
    }
end

local function update_science_pack(pack_table, science_pack_data)
    if not science_pack_data then return end
    local science_pack = science_pack_data.science_pack
    pack_table.parent.non_made.visible = false

    -- Update the icon
    --- @type LuaGuiElement
    local pack_icon = pack_table["icon-" .. science_pack] or science_pack_base(pack_table, science_pack_data)
    local icon_style = science_pack_data.icon_style
    pack_icon.style = icon_style

    local pack_icon_style = pack_icon.style
    pack_icon_style.height = 55
    if icon_style == "slot_button" then
        pack_icon_style.padding = { 0, -2 }
        pack_icon_style.width = 36
    end

    -- Update the production labels
    local delta_table = pack_table["delta-" .. science_pack].table
    update_production_label(delta_table, science_pack_data.positive)
    update_production_label(delta_table, science_pack_data.negative)
    update_production_label(pack_table, science_pack_data.net)
end

--- Gets the data that is used with the eta label
local function get_eta_label_data(player)
    local force = player.force

    -- If there is no current research then return no research
    local research = force.current_research
    if not research then
        return { research = false }
    end

    local limit
    local progress = force.research_progress
    local remaining = research.research_unit_count * (1 - progress)

    -- Check for the limiting science pack
    for _, ingredient in pairs(research.research_unit_ingredients) do
        local pack_name = ingredient.name
        local required = ingredient.amount * remaining
        local time = Production.get_consumsion_eta(force, pack_name, defines.flow_precision_index.one_minute, required)
        if not limit or limit < time then
            limit = time
        end
    end

    -- Return the caption and tooltip
    return limit and limit > 0 and {
        research = true,
        caption = clock_time_format(limit),
        tooltip = long_time_format(limit),
    } or {
        research = false
    }
end

-- Updates the eta label
local function update_eta_label(element, eta_label_data)
    -- If no research selected show null
    if not eta_label_data.research then
        element.caption = null_time_clock
        element.tooltip = null_time_long
        return
    end

    -- Update the element
    element.caption = { "science-info.eta-time", eta_label_data.caption }
    element.tooltip = eta_label_data.tooltip
end

--- Main task list container for the left flow
-- @element task_list_container
local science_info = Gui.element("science_info")
    :draw(function(def, parent)
        local player = Gui.get_player(parent)

        -- Draw the internal container
        local container = Gui.elements.container(parent, 200)

        -- Draw the header
        Gui.elements.header(container, {
            caption = { "science-info.main-caption" },
            tooltip = { "science-info.main-tooltip" },
        })

        -- Draw the scroll table for the tasks
        local scroll_table = Gui.elements.scroll_table(container, 178, 4, "scroll")

        -- Draw the no packs label
        local no_packs_label =
            scroll_table.parent.add{
                name = "non_made",
                type = "label",
                caption = { "science-info.no-packs" },
            }

        -- Change the style of the no packs label
        local no_packs_style = no_packs_label.style
        no_packs_style.padding = { 2, 4 }
        no_packs_style.single_line = false
        no_packs_style.width = 200

        -- Add the footer and eta
        if config.show_eta then
            -- Draw the footer
            local footer = Gui.elements.footer(container, {
                name = "footer",
                caption = { "science-info.eta-caption" },
                tooltip = { "science-info.eta-tooltip" },
            })

            -- Draw the eta label
            local eta_label =
                footer.add{
                    name = "label",
                    type = "label",
                    caption = null_time_clock,
                    tooltip = null_time_long,
                    style = "frame_title",
                }

            -- Update the eta
            update_eta_label(eta_label, get_eta_label_data(player))
        end

        -- Add packs which have been made
        for _, science_pack in ipairs(config) do
            update_science_pack(scroll_table, get_science_pack_data(player, science_pack))
        end

        -- Return the external container
        return container.parent
    end)

--- Add the element to the left flow with a toolbar button
Gui.add_left_element(science_info, false)
Gui.toolbar.create_button{
    name = "science_info_toggle",
    left_element = science_info,
    sprite = "entity/lab",
    tooltip = { "science-info.main-tooltip" },
    visible = function(player, element)
        return Roles.player_allowed(player, "gui/science-info")
    end
}

--- Updates the gui every 1 second
Event.on_nth_tick(60, function()
    local force_pack_data = {}
    local force_eta_data = {}
    for _, player in pairs(game.connected_players) do
        local force_name = player.force.name
        local container = Gui.get_left_element(science_info, player)
        local frame = container.frame

        -- Update the science packs
        local scroll_table = frame.scroll.table
        local pack_data = force_pack_data[force_name]
        if not pack_data then
            -- No data in cache so it needs to be generated
            pack_data = {}
            force_pack_data[force_name] = pack_data
            for _, science_pack in ipairs(config) do
                local next_data = get_science_pack_data(player, science_pack)
                pack_data[science_pack] = next_data
                update_science_pack(scroll_table, next_data)
            end
        else
            -- Data found in cache is no need to generate it
            for _, next_data in pairs(pack_data) do
                update_science_pack(scroll_table, next_data)
            end
        end

        -- Update the eta times
        if not config.show_eta then return end
        local eta_label = frame.footer.flow.label
        local eta_data = force_eta_data[force_name]
        if not eta_data then
            -- No data in chache so it needs to be generated
            eta_data = get_eta_label_data(player)
            force_eta_data[force_name] = eta_data
            update_eta_label(eta_label, eta_data)
        else
            -- Data found in chache is no need to generate it
            update_eta_label(eta_label, eta_data)
        end
    end
end)
