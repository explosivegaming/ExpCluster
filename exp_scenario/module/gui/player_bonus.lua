--[[-- Gui - Player Bonus
Adds a gui that allows players to apply various bonuses
]]

local Gui = require("modules/exp_gui")
local Roles = require("modules/exp_legacy/expcore/roles")
local config = require("modules/exp_legacy/config/bonus")
local vlayer = require("modules/exp_legacy/modules/control/vlayer")
local format_number = require("util").format_number

--- @class ExpGui_PlayerBonus.elements
local Elements = {}

--- @class ExpGui_PlayerBonus.bonus_data
--- @field name string
--- @field cost number
--- @field scale number
--- @field max_value number
--- @field initial_value number
--- @field is_percentage boolean
--- @field is_special boolean
--- @field value_step number
--- @field _cost_scale number

--- For perf calculate the division of scale against cost ahead of time
for _, bonus_data in pairs(config.player_bonus) do
    bonus_data._cost_scale = bonus_data.cost / bonus_data.scale
end

--- Progress bar which displays how much of a bonus has been used
--- @class ExpGui_PlayerBonus.elements.bonus_used: ExpElement
--- @field data number
--- @overload fun(parent: LuaGuiElement): LuaGuiElement
Elements.bonus_used = Gui.define("player_bonus/bonus_used")
    :track_all_elements()
    :draw{
        type = "progressbar",
        caption = "0 / 0",
        value = 0,
        style = "electric_satisfaction_statistics_progressbar",
    }
    :style{
        width = 150,
        height = 24,
        font = "heading-2",
        color = { 1, 0, 0 },
    }
    :element_data(0) --[[ @as any ]]

--- Value is cached to save perf
--- @type table<number, number>
do local _points_limit = {}
    --- Clear the cache for points limit
    --- @param player LuaPlayer
    function Elements.bonus_used._clear_points_limit_cache(player)
        _points_limit[player.index] = nil
    end

    --- Clear the cache for points limit
    --- @param player LuaPlayer
    --- @return number
    function Elements.bonus_used.calculate_points_limit(player)
        return _points_limit[player.index] or Elements.bonus_used._calculate_points_limit(player)
    end

    --- Calculate the bonus limit for a player
    --- @param player LuaPlayer
    --- @return number
    function Elements.bonus_used._calculate_points_limit(player)
        local role_diff = Roles.get_role_by_name(config.points.role_name).index - Roles.get_player_highest_role(player).index
        local points_limit = math.floor(config.points.base * (1 + config.points.increase_percentage_per_role_level * role_diff))
        _points_limit[player.index] = points_limit
        return points_limit
    end
end

--- Refresh a bonus used slider to the current bonus cost
--- @param bonus_used LuaGuiElement
--- @param bonus_cost number
--- @return boolean
function Elements.bonus_used.refresh(bonus_used, bonus_cost)
    local player = Gui.get_player(bonus_used)
    local limit = Elements.bonus_used.calculate_points_limit(player)
    Elements.bonus_used.data[bonus_used] = bonus_cost
    bonus_used.caption = bonus_cost .. " / " .. limit
    bonus_used.value = bonus_cost / limit
    return bonus_cost <= limit
end

--- Refresh all bonus used sliders for a player
--- @param player LuaPlayer
--- @param bonus_cost number
--- @return boolean
function Elements.bonus_used.refresh_player(player, bonus_cost)
    local limit = Elements.bonus_used.calculate_points_limit(player)
    for _, bonus_used in Elements.bonus_used:tracked_elements(player) do
        Elements.bonus_used.data[bonus_used] = bonus_cost
        bonus_used.caption = bonus_cost .. " / " .. limit
        bonus_used.value = bonus_cost / limit
    end
    return bonus_cost <= limit
end

--- Update the element caption and value with a delta bonus cost
--- @param bonus_used LuaGuiElement
--- @param delta number
--- @return boolean
function Elements.bonus_used.update(bonus_used, delta)
    local player = Gui.get_player(bonus_used)
    local limit = Elements.bonus_used.calculate_points_limit(player)
    local bonus_cost = Elements.bonus_used.data[bonus_used] + delta
    Elements.bonus_used.data[bonus_used] = bonus_cost
    bonus_used.caption = bonus_cost .. " / " .. limit
    bonus_used.value = bonus_cost / limit
    return bonus_cost <= limit
end

--- Reset all sliders to before they were edited
--- @class ExpGui_PlayerBonus.elements.reset_button: ExpElement
--- @field data table<LuaGuiElement, { bonus_table: LuaGuiElement, bonus_used: LuaGuiElement, apply_button: LuaGuiElement? }>
--- @overload fun(parent: LuaGuiElement, bonus_table: LuaGuiElement, bonus_used: LuaGuiElement): LuaGuiElement
Elements.reset_button = Gui.define("player_bonus/reset_button")
    :draw{
        type = "sprite-button",
        sprite = "utility/reset",
        tooltip = { "exp-gui_player-bonus.tooltip-reset" },
        style = "shortcut_bar_button_red",
        enabled = false,
    }
    :style{
        size = 26,
    }
    :element_data{
        bonus_table = Gui.from_argument(1),
        bonus_used = Gui.from_argument(2),
    }
    :on_click(function(def, player, element)
        --- @cast def ExpGui_PlayerBonus.elements.reset_button
        element.enabled = false

        local element_data = def.data[element]
        if element_data.apply_button then
            element_data.apply_button.enabled = false
        end

        Elements.bonus_table.reset_sliders(element_data.bonus_table)
        local bonus_cost = Elements.bonus_table.calculate_cost(element_data.bonus_table)
        Elements.bonus_used.refresh(element_data.bonus_used, bonus_cost)
    end) --[[ @as any ]]

--- Link an apply button to this reset button so that it will be disabled after being pressed
--- @param reset_button LuaGuiElement
--- @param apply_button LuaGuiElement
function Elements.reset_button.link_apply_button(reset_button, apply_button)
    Elements.reset_button.data[reset_button].apply_button = apply_button
end

--- Apply the bonus for a player
--- @class ExpGui_PlayerBonus.elements.apply_button: ExpElement
--- @field data table<LuaGuiElement, { bonus_table: LuaGuiElement, bonus_used: LuaGuiElement, reset_button: LuaGuiElement? }>
--- @overload fun(parent: LuaGuiElement, bonus_table: LuaGuiElement, bonus_used: LuaGuiElement): LuaGuiElement
Elements.apply_button = Gui.define("player_bonus/apply_button")
    :draw{
        type = "sprite-button",
        sprite = "utility/confirm_slot",
        tooltip = { "exp-gui_player-bonus.tooltip-apply" },
        style = "shortcut_bar_button_green",
        enabled = false,
    }
    :style{
        size = 26,
    }
    :element_data{
        bonus_table = Gui.from_argument(1),
        bonus_used = Gui.from_argument(2),
    }
    :on_click(function(def, player, element)
        --- @cast def ExpGui_PlayerBonus.elements.apply_button
        element.enabled = false
        local element_data = def.data[element]
        if element_data.reset_button then
            element_data.reset_button.enabled = false
        end

        local bonus_cost = Elements.bonus_table.calculate_cost(element_data.bonus_table)
        if Elements.bonus_used.refresh(element_data.bonus_used, bonus_cost) then
            Elements.bonus_table.save_sliders(element_data.bonus_table)
            Elements.container.apply_player_bonus(player)
        end
    end) --[[ @as any ]]

--- Link an apply button to this reset button so that it will be disabled after being pressed
--- @param apply_button LuaGuiElement
--- @param reset_button LuaGuiElement
function Elements.apply_button.link_reset_button(apply_button, reset_button)
    Elements.apply_button.data[apply_button].reset_button = reset_button
end

--- Label used within the bonus table
--- @class ExpGui_PlayerBonus.elements.bonus_table_label: ExpElement
--- @overload fun(parent: LuaGuiElement, caption: LocalisedString?, tooltip: LocalisedString?, width: number?)
Elements.bonus_table_label = Gui.define("player_bonus/table_label")
    :draw{
        type = "label",
        caption = Gui.from_argument(1),
        tooltip = Gui.from_argument(2),
        style = "heading_2_label",
    }
    :style{
        width = Gui.from_argument(3, 70),
    } --[[ @as any ]]

--- @class ExpGui_PlayerBonus.elements.bonus_slider.elements
--- @field bonus_used LuaGuiElement
--- @field reset_button LuaGuiElement
--- @field apply_button LuaGuiElement

--- @class ExpGui_PlayerBonus.elements.bonus_slider.data: ExpGui_PlayerBonus.elements.bonus_slider.elements
--- @field previous_value number
--- @field label LuaGuiElement
--- @field bonus_data ExpGui_PlayerBonus.bonus_data

--- Slider and label pair used for selecting bonus amount
--- @class ExpGui_PlayerBonus.elements.bonus_slider: ExpElement
--- @field data table<LuaGuiElement, ExpGui_PlayerBonus.elements.bonus_slider.data>
--- @overload fun(parent: LuaGuiElement, bonus_data: ExpGui_PlayerBonus.bonus_data, elements: ExpGui_PlayerBonus.elements.bonus_slider.elements)
Elements.bonus_slider = Gui.define("player_bonus/bonus_slider")
    :draw(function(def, parent, bonus_data, elements)
        local player = Gui.get_player(parent)
        local value = Elements.container.get_player_bonus(player, bonus_data.name)
        if not value then
            value = bonus_data.initial_value
            elements.apply_button.enabled = true
        end

        local slider = parent.add{
            type = "slider",
            value = value,
            maximum_value = bonus_data.max_value,
            value_step = bonus_data.value_step,
            discrete_values = true,
            style = "notched_slider",
        }
        slider.style.width = 180
        slider.style.horizontally_stretchable = true

        local slider_caption = Elements.bonus_slider.calculate_slider_caption(bonus_data, value)
        def.data[slider] = {
            label = Elements.bonus_table_label(parent, slider_caption, nil, 50),
            previous_value = value,
            bonus_data = bonus_data,
            bonus_used = elements.bonus_used,
            reset_button = elements.reset_button,
            apply_button = elements.apply_button,
        }

        return slider
    end)
    :on_value_changed(function(def, player, element, event)
        --- @cast def ExpGui_PlayerBonus.elements.bonus_slider
        local value = element.slider_value
        local element_data = def.data[element]
        local bonus_data = element_data.bonus_data
        local value_change = value - element_data.previous_value
        element_data.previous_value = value
        element_data.label.caption = Elements.bonus_slider.calculate_slider_caption(bonus_data, value)
        element_data.apply_button.enabled = Elements.bonus_used.update(element_data.bonus_used, value_change * bonus_data._cost_scale)
        element_data.reset_button.enabled = true
    end) --[[ @as any ]]

--- Get the caption of the slider label
--- @param bonus_data ExpGui_PlayerBonus.bonus_data
--- @param value number
--- @return LocalisedString
function Elements.bonus_slider.calculate_slider_caption(bonus_data, value)
    return bonus_data.is_percentage and format_number(value * 100, false) .. " %" or format_number(value, false)
end

--- Calculate the cost of a slider
--- @param slider LuaGuiElement
--- @return number
function Elements.bonus_slider.calculate_cost(slider)
    local bonus_data = Elements.bonus_slider.data[slider].bonus_data
    return slider.slider_value * bonus_data._cost_scale
end

--- Reset a slider to its original value
--- @param slider LuaGuiElement
function Elements.bonus_slider.reset_value(slider)
    local player = Gui.get_player(slider)
    local element_data = Elements.bonus_slider.data[slider]
    local bonus_data = element_data.bonus_data
    local value = Elements.container.get_player_bonus(player, bonus_data.name) or bonus_data.initial_value
    slider.slider_value = value
    element_data.label.caption = Elements.bonus_slider.calculate_slider_caption(bonus_data, value)
    element_data.previous_value = value
end

--- Save a slider at its current value
--- @param slider LuaGuiElement
function Elements.bonus_slider.save_value(slider)
    local player = Gui.get_player(slider)
    local bonus_data = Elements.bonus_slider.data[slider].bonus_data
    Elements.container.set_player_bonus(player, bonus_data.name, slider.slider_value)
end

--- A table containing all of the bonus sliders and their label
--- @class ExpGui_PlayerBonus.elements.bonus_table: ExpElement
--- @field data table<LuaGuiElement, LuaGuiElement[]>
--- @overload fun(parent: LuaGuiElement): LuaGuiElement
Elements.bonus_table = Gui.define("player_bonus/bonus_table")
    :draw(function(_, parent)
        return Gui.elements.scroll_table(parent, 300, 3)
    end)
    :element_data{} --[[ @as any ]]

--- Adds a row to the milestone table
--- @param bonus_table LuaGuiElement
--- @param elements ExpGui_PlayerBonus.elements.bonus_slider.elements
--- @param bonus_data ExpGui_PlayerBonus.bonus_data
function Elements.bonus_table.add_row(bonus_table, bonus_data, elements)
    local rows = Elements.bonus_table.data[bonus_table]
    Elements.bonus_table_label(bonus_table, { "exp-gui_player-bonus.caption-" .. bonus_data.name }, { "exp-gui_player-bonus.tooltip-" .. bonus_data.name })
    rows[#rows + 1] = Elements.bonus_slider(bonus_table, bonus_data, elements)
end

--- Calculate the total cost of a table
--- @param bonus_table LuaGuiElement
--- @return number
function Elements.bonus_table.calculate_cost(bonus_table)
    local cost = 0
    for _, slider in pairs(Elements.bonus_table.data[bonus_table]) do
        cost = cost + Elements.bonus_slider.calculate_cost(slider)
    end
    return cost
end

--- Reset all sliders in the table to their original positions
--- @param bonus_table LuaGuiElement
function Elements.bonus_table.reset_sliders(bonus_table)
    for _, slider in pairs(Elements.bonus_table.data[bonus_table]) do
        Elements.bonus_slider.reset_value(slider)
    end
end

--- Save all sliders at their current position
--- @param bonus_table LuaGuiElement
function Elements.bonus_table.save_sliders(bonus_table)
    for _, slider in pairs(Elements.bonus_table.data[bonus_table]) do
        Elements.bonus_slider.save_value(slider)
    end
end

--- Container added to the left gui flow
--- @class ExpGui_PlayerBonus.elements.container: ExpElement
--- @field data table<LuaPlayer, { [string]: number }>
Elements.container = Gui.define("player_bonus/container")
    :draw(function(def, parent)
        local container = Gui.elements.container(parent)
        local header = Gui.elements.header(container, { caption = { "exp-gui_player-bonus.caption-main" } })

        local elements = {} --- @cast elements ExpGui_PlayerBonus.elements.bonus_slider.elements
        local bonus_table = Elements.bonus_table(container)
        elements.bonus_used = Elements.bonus_used(header)
        elements.reset_button = Elements.reset_button(header, bonus_table, elements.bonus_used)
        elements.apply_button = Elements.apply_button(header, bonus_table, elements.bonus_used)
        Elements.reset_button.link_apply_button(elements.reset_button, elements.apply_button)
        Elements.apply_button.link_reset_button(elements.apply_button, elements.reset_button)

        for _, bonus_data in pairs(config.player_bonus) do
            --- @cast bonus_data ExpGui_PlayerBonus.bonus_data
            Elements.bonus_table.add_row(bonus_table, bonus_data, elements)
        end

        local bonus_cost = Elements.bonus_table.calculate_cost(bonus_table)
        Elements.bonus_used.refresh(elements.bonus_used, bonus_cost)

        return Gui.elements.container.get_root_element(container)
    end)
    :player_data{} --[[ @as any ]]

--- Set the bonus value for a player
--- @param player LuaPlayer
--- @param name string
--- @param value number
function Elements.container.set_player_bonus(player, name, value)
    Elements.container.data[player][name] = value
end

--- Get the bonus value for a player
--- @param player LuaPlayer
--- @param name string
--- @return number
function Elements.container.get_player_bonus(player, name)
    return Elements.container.data[player][name]
end

--- Clear all bonus values for a player
--- @param player LuaPlayer
function Elements.container.clear_player_bonus(player)
    Elements.container.data[player] = {}
    for _, bonus_data in pairs(config.player_bonus) do
        if not bonus_data.is_special then
            player[bonus_data.name] = 0
            if bonus_data.combined_bonus then
                for _, name in ipairs(bonus_data.combined_bonus) do
                    player[name] = 0
                end
            end
        end
    end
end

--- Apply all bonus values for a player
--- @param player LuaPlayer
function Elements.container.apply_player_bonus(player)
    if not player.character then
        return
    end

    local player_data = Elements.container.data[player]
    for _, bonus_data in pairs(config.player_bonus) do
        if not bonus_data.is_special then
            local value = player_data[bonus_data.name] or 0
            player[bonus_data.name] = value
            if bonus_data.combined_bonus then
                for _, name in ipairs(bonus_data.combined_bonus) do
                    player[name] = value
                end
            end
        end
    end
end

--- Calculate the current cost for a player
--- @param player LuaPlayer
--- @return number
function Elements.container.calculate_cost(player)
    local cost = 0
    local player_data = Elements.container.data[player]
    for _, bonus_data in pairs(config.player_bonus) do
        cost = cost + (player_data[bonus_data.name] or 0) * bonus_data._cost_scale
    end
    return cost
end

--- Add the element to the left flow with a toolbar button
Gui.add_left_element(Elements.container, false)
Gui.toolbar.create_button{
    name = "toggle_player_bonus",
    left_element = Elements.container,
    sprite = "item/exoskeleton-equipment",
    tooltip = { "exp-gui_player-bonus.tooltip-main" },
    visible = function(player, element)
        return Roles.player_allowed(player, "gui/bonus")
    end
}

--- Recalculate and apply the bonus for a player
local function recalculate_bonus(event)
    local player = assert(game.get_player(event.player_index))
    if event.name == Roles.events.on_role_assigned or event.name == Roles.events.on_role_unassigned then
        -- If the player's roles changed then we will need to recalculate their limit
        Elements.bonus_used._clear_points_limit_cache(player)
        local bonus_cost = Elements.container.calculate_cost(player)
        local within_limit = Elements.bonus_used.refresh_player(player, bonus_cost)
        if not within_limit or not Roles.player_allowed(player, "gui/bonus") then
            Elements.container.clear_player_bonus(player)
            return
        end
    end

    Elements.container.apply_player_bonus(player)
end

--- Apply periodic bonus to a player
--- @param player LuaPlayer
local function apply_personal_battery_recharge(player)
    local available_energy = vlayer.get_statistics()["energy_storage"]
    if available_energy <= 0 then
        return -- No power to give
    end

    local armor = player.get_inventory(defines.inventory.character_armor)
    if not armor or not armor[1] or not armor[1].valid_for_read then
        return -- No armor
    end

    local grid = armor[1].grid
    if not grid or grid.available_in_batteries >= grid.battery_capacity then
        return -- No grid or already full
    end

    local recharge_amount = Elements.container.get_player_bonus(player, "personal_battery_recharge") * 100000 * config.periodic_bonus_rate / 6

    for _, equipment in pairs(grid.equipment) do
        if equipment.energy < equipment.max_energy then
            local energy_to_give = math.min(math.floor(equipment.max_energy - equipment.energy), available_energy, recharge_amount)
            equipment.energy = equipment.energy + energy_to_give
            recharge_amount = recharge_amount - energy_to_give
            available_energy = vlayer.energy_changed(-energy_to_give)
        end
    end
end

--- Apply the periodic bonus to all players
local function apply_periodic_bonus_online()
    for _, player in pairs(game.connected_players) do
        if player.character and Roles.player_allowed(player, "gui/bonus") then
            apply_personal_battery_recharge(player)
        end
    end
end

local e = defines.events

return {
    elements = Elements,
    events = {
        [e.on_player_respawned] = recalculate_bonus,
        [Roles.events.on_role_assigned] = recalculate_bonus,
        [Roles.events.on_role_unassigned] = recalculate_bonus,
    },
    on_nth_tick = {
        [config.periodic_bonus_rate] = apply_periodic_bonus_online,
    }
}
