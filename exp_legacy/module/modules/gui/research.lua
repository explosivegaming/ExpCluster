--- research gui
-- @gui Research

local ExpUtil = require("modules/exp_util")
local Gui = require("modules/exp_gui")
local Storage = require("modules/exp_util/storage")
local Event = require("modules/exp_legacy/utils/event") --- @dep utils.event
local Roles = require("modules.exp_legacy.expcore.roles") --- @dep expcore.roles
local config = require("modules.exp_legacy.config.research") --- @dep config.research

local table_to_json = helpers.table_to_json
local write_file = helpers.write_file

local research = {
    time = {},
    res_queue_enable = false
}

Storage.register(research, function(tbl)
    research = tbl
end)

for i = 1, #config.mod_set_lookup do
    if script.active_mods[config.mod_set_lookup[i]] then
        config.mod_set = config.mod_set_lookup[i]
        break
    end
end

local research_time_format = ExpUtil.format_time_factory{ format = "clock", hours = true, minutes = true, seconds = true }
local empty_time = research_time_format(nil)

local font_color = {
    -- positive
    [1] = { r = 0.3, g = 1, b = 0.3 },
    -- negative
    [2] = { r = 1, g = 0.3, b = 0.3 },
}

local res = {
    ["lookup_name"] = {},
    ["disp"] = {},
}

do
    local res_total = 0
    local i = 1

    for k, v in pairs(config.milestone[config.mod_set]) do
        research.time[i] = 0
        res["lookup_name"][k] = i
        res_total = res_total + v * 60

        res["disp"][i] = {
            raw_name = k,
            target = res_total,
            target_disp = research_time_format(res_total),
        }

        i = i + 1
    end
end

local function research_add_log()
    local result_data = {}

    for i = 1, #research.time, 1 do
        result_data[res["disp"][i]["raw_name"]] = research.time[i]
    end

    write_file(config.file_name, table_to_json(result_data) .. "\n", true, 0)
end

local function research_res_n(res_)
    local res_n = 1

    for k, _ in pairs(res_) do
        if research.time[k] == 0 then
            res_n = k - 1
            break
        end
    end

    if research.time[#res_] and research.time[#res_] > 0 then
        if res_n == 1 then
            res_n = #res_
        end
    end

    if res_n < 3 then
        res_n = 3
    elseif res_n > (#research.time - 5) then
        res_n = #research.time - 5
    end

    return res_n
end

local function research_notification(event)
    if config.inf_res[config.mod_set][event.research.name] then
        if event.research.name == config.bonus_inventory.res[config.mod_set].name then
            if event.research.level == config.bonus_inventory.res[config.mod_set].level + 1 then
                -- Add run result to log
                research_add_log()
            end

            if config.bonus_inventory.enabled then
                if (event.research.level - 1) <= math.ceil(config.bonus_inventory.limit / config.bonus_inventory.rate) then
                    event.research.force[config.bonus_inventory.name] = math.max((event.research.level - 1) * config.bonus_inventory.rate, config.bonus_inventory.limit)
                end
            end

            if config.pollution_ageing_by_research then
                game.map_settings.pollution.ageing = math.min(10, event.research.level / 5)
            end
        else
            if not (event.by_script) then
                game.print{ "research.inf", research_time_format(game.tick), event.research.name, event.research.level - 1 }
            end
        end
    else
        if not (event.by_script) then
            game.print{ "research.msg", research_time_format(game.tick), event.research.name }
        end

        if config.bonus_inventory.enabled then
            if event.research.name == "mining-productivity-1" or event.research.name == "mining-productivity-2" or event.research.name == "mining-productivity-3" then
                event.research.force[config.bonus_inventory.name] = event.research.level * config.bonus_inventory.rate
            end
        end
    end
end

local function research_gui_update()
    local res_disp = {}
    local res_n = research_res_n(res["disp"])

    for i = 1, 8, 1 do
        res_disp[i] = {
            ["name"] = "",
            ["target"] = "",
            ["attempt"] = "",
            ["difference"] = "",
            ["difference_color"] = font_color[1],
        }

        local res_i = res_n + i - 3

        if res["disp"][res_i] then
            res_disp[i]["name"] = { "research.res-name", res["disp"][res_i]["raw_name"], prototypes.technology[res["disp"][res_i]["raw_name"]].localised_name }

            if research.time[res_i] == 0 then
                res_disp[i]["target"] = res["disp"][res_i].target_disp
                res_disp[i]["attempt"] = empty_time
                res_disp[i]["difference"] = empty_time
                res_disp[i]["difference_color"] = font_color[1]
            else
                res_disp[i]["target"] = res["disp"][res_i].target_disp
                res_disp[i]["attempt"] = research_time_format(research.time[res_i])

                if research.time[res_i] < res["disp"][res_i].target then
                    res_disp[i]["difference"] = "-" .. research_time_format(res["disp"][res_i].target - research.time[res_i])
                    res_disp[i]["difference_color"] = font_color[1]
                else
                    res_disp[i]["difference"] = research_time_format(research.time[res_i] - res["disp"][res_i].target)
                    res_disp[i]["difference_color"] = font_color[2]
                end
            end
        end
    end

    return res_disp
end

--- Display label for the clock display
-- @element research_gui_clock_display
local research_gui_clock = Gui.element("research_gui_clock")
    :draw{
        type = "label",
        name = Gui.property_from_name,
        caption = empty_time,
        style = "heading_2_label",
    }

--- A vertical flow containing the clock
-- @element research_clock_set
local research_clock_set = Gui.element("research_clock_set")
    :draw(function(_, parent, name)
        local research_set = parent.add{ type = "flow", direction = "vertical", name = name }
        local disp = Gui.elements.scroll_table(research_set, 390, 1, "disp")

        research_gui_clock(disp)

        return research_set
    end)

--- Display group
-- @element research_data_group
local research_data_group = Gui.element("research_data_group")
    :draw(function(_def, parent, i)
        local name = parent.add{
            type = "label",
            name = "research_" .. i .. "_name",
            caption = "",
            style = "heading_2_label",
        }
        name.style.width = 180
        name.style.horizontal_align = "left"

        local target = parent.add{
            type = "label",
            name = "research_" .. i .. "_target",
            caption = "",
            style = "heading_2_label",
        }
        target.style.width = 70
        target.style.horizontal_align = "right"

        local attempt = parent.add{
            type = "label",
            name = "research_" .. i .. "_attempt",
            caption = "",
            style = "heading_2_label",
        }
        attempt.style.width = 70
        attempt.style.horizontal_align = "right"

        local difference = parent.add{
            type = "label",
            name = "research_" .. i .. "_difference",
            caption = "",
            style = "heading_2_label",
        }
        difference.style.width = 70
        difference.style.horizontal_align = "right"
        difference.style.font_color = font_color[1]
    end)

--- A vertical flow containing the data
-- @element research_data_set
local research_data_set = Gui.element("research_data_set")
    :draw(function(_, parent, name)
        local research_set = parent.add{ type = "flow", direction = "vertical", name = name }
        local disp = Gui.elements.scroll_table(research_set, 390, 4, "disp")
        local res_disp = research_gui_update()

        research_data_group(disp, 0)
        disp["research_0_name"].caption = { "research.name" }
        disp["research_0_target"].caption = { "research.target" }
        disp["research_0_attempt"].caption = { "research.attempt" }
        disp["research_0_difference"].caption = { "research.difference" }

        for i = 1, 8, 1 do
            research_data_group(disp, i)

            local research_name_i = "research_" .. i

            disp[research_name_i .. "_name"].caption = res_disp[i]["name"]
            disp[research_name_i .. "_target"].caption = res_disp[i]["target"]
            disp[research_name_i .. "_attempt"].caption = res_disp[i]["attempt"]
            disp[research_name_i .. "_difference"].caption = res_disp[i]["difference"]
            disp[research_name_i .. "_difference"].style.font_color = res_disp[i]["difference_color"]
        end

        return research_set
    end)

local research_container = Gui.element("research_container")
    :draw(function(def, parent)
        local container = Gui.elements.container(parent, 390)

        research_clock_set(container, "research_st_1")
        research_data_set(container, "research_st_2")

        return container.parent
    end)

--- Add the element to the left flow with a toolbar button
Gui.add_left_element(research_container, false)
Gui.toolbar.create_button{
    name = "research_toggle",
    left_element = research_container,
    sprite = "item/space-science-pack",
    tooltip = { "research.main-tooltip" },
    visible = function(player, element)
        return Roles.player_allowed(player, "gui/research")
    end
}

Event.add(defines.events.on_research_finished, function(event)
    research_notification(event)

    if res["lookup_name"][event.research.name] == nil then
        return
    end

    local n_i = res["lookup_name"][event.research.name]
    research.time[n_i] = game.tick

    local res_disp = research_gui_update()

    for _, player in pairs(game.connected_players) do
        local container = Gui.get_left_element(research_container, player)
        local disp = container.frame["research_st_2"].disp.table

        for i = 1, 8, 1 do
            local research_name_i = "research_" .. i

            disp[research_name_i .. "_name"].caption = res_disp[i]["name"]
            disp[research_name_i .. "_target"].caption = res_disp[i]["target"]
            disp[research_name_i .. "_attempt"].caption = res_disp[i]["attempt"]
            disp[research_name_i .. "_difference"].caption = res_disp[i]["difference"]
            disp[research_name_i .. "_difference"].style.font_color = res_disp[i]["difference_color"]
        end
    end
end)

Event.on_nth_tick(60, function()
    local current_time = research_time_format(game.tick)

    for _, player in pairs(game.connected_players) do
        local container = Gui.get_left_element(research_container, player)
        local disp = container.frame["research_st_1"].disp.table
        disp[research_gui_clock.name].caption = current_time
    end
end)
