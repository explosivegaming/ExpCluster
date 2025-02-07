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

for _, mod_name in ipairs(config.mod_set_lookup) do
    if script.active_mods[mod_name] then
        config.mod_set = mod_name
        break
    end
end

local research_time_format = ExpUtil.format_time_factory{ format = "clock", hours = true, minutes = true, seconds = true }
local empty_time = research_time_format(nil)

local font_color = {
    ["neutral"] = { r = 1, g = 1, b = 1 },
    ["positive"] = { r = 0.3, g = 1, b = 0.3 },
    ["negative"] = { r = 1, g = 0.3, b = 0.3 },
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

    for i = 1, #research.time do
        result_data[res["disp"][i]["raw_name"]] = research.time[i]
    end

    write_file(config.file_name, table_to_json(result_data) .. "\n", true, 0)
end

local function research_res_n()
    local current = #res.disp + 1

    for i = 1, #res.disp do
        if research.time[i] == 0 then
            current = i
            break
        end
    end

    local max_start = math.max(1, #res.disp - 7)
    local start = math.clamp(current - 3, 1, max_start)
    return math.min(start, max_start)
end

local function research_notification(event)
    if config.inf_res[config.mod_set][event.research.name] then
        if event.research.name == config.bonus_inventory.res[config.mod_set].name then
            if event.research.level == config.bonus_inventory.res[config.mod_set].level + 1 then
                -- Add run result to log
                research_add_log()
            end

            if config.bonus_inventory.enabled then
                event.research.force[config.bonus_inventory.name] = math.max((event.research.level - 1) * config.bonus_inventory.rate, config.bonus_inventory.limit)
            end

            if config.pollution_ageing_by_research then
                game.map_settings.pollution.ageing = math.min(10, event.research.level / 5)
            end
        end

        if not (event.by_script) then
            game.print{ "research.inf", research_time_format(game.tick), event.research.name, event.research.level - 1 }
        end
    else
        if not (event.by_script) then
            game.print{ "research.msg", research_time_format(game.tick), event.research.name }
        end

        if config.bonus_inventory.enabled and (event.research.name == "mining-productivity-1" or event.research.name == "mining-productivity-2" or event.research.name == "mining-productivity-3") then
            event.research.force[config.bonus_inventory.name] = event.research.level * config.bonus_inventory.rate
        end
    end

    if config.limit_res[event.research.name] and event.research.level > config.limit_res[event.research.name] then
        event.research.enabled = false
        event.research.visible_when_disabled = true
        local rq = event.research.force.research_queue

        for i = #rq, 1, -1 do
            if rq[i] == event.research.name then
                table.remove(rq, i)
            end
        end

        event.research.force.cancel_current_research()
        event.research.force.research_queue = rq
    end
end

local function research_gui_update()
    local res_disp = {}
    local res_n = research_res_n()

    for i = 1, 8 do
        local res_i = res_n + i - 1
        local entry = res.disp[res_i] or {}
        local data = {
            name = "",
            target = "",
            attempt = "",
            difference = "",
            color = font_color["positive"]
        }

        if entry.raw_name then
            data.name = { "research.res-name", entry.raw_name, prototypes.technology[entry.raw_name].localised_name }
            data.target = entry.target_disp

            if research.time[res_i] == 0 then
                data.attempt = empty_time
                data.difference = empty_time

            else
                data.attempt = research_time_format(research.time[res_i])
                local diff = research.time[res_i] - entry.target
                data.difference = (diff < 0 and "-" or "") .. research_time_format(math.abs(diff))
                data.color = (diff < 0 and font_color["positive"]) or font_color["negative"]
            end
        end

        res_disp[i] = data
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
        local labels = { "name", "target", "attempt", "difference" }

        for _, label in ipairs(labels) do
            local elem = parent.add{
                type = "label",
                name = "research_" .. i .. "_" .. label,
                caption = "",
                style = "heading_2_label"
            }
            elem.style.minimal_width = (label == "name" and 180) or 70
            elem.style.horizontal_align = (label == "name" and "left") or "right"
            elem.style.font_color = (label == "difference" and font_color["positive"]) or font_color["neutral"]
        end
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
        disp["research_0_difference"].style.font_color = font_color["neutral"]

        for i = 1, 8 do
            research_data_group(disp, i)
            local research_name_i = "research_" .. i
            disp[research_name_i .. "_name"].caption = res_disp[i]["name"]
            disp[research_name_i .. "_target"].caption = res_disp[i]["target"]
            disp[research_name_i .. "_attempt"].caption = res_disp[i]["attempt"]
            disp[research_name_i .. "_difference"].caption = res_disp[i]["difference"]
            disp[research_name_i .. "_difference"].style.font_color = res_disp[i]["color"]
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
    local research_name = event.research.name

    if not res["lookup_name"][research_name] then
        return
    end

    research.time[res.lookup_name[research_name]] = game.tick

    local res_disp = research_gui_update()

    for _, player in pairs(game.connected_players) do
        if Roles.player_allowed(player, "gui/research") then
            local container = Gui.get_left_element(research_container, player)
            local disp = container.frame["research_st_2"].disp.table

            for i = 1, 8 do
                local research_name_i = "research_" .. i
                disp[research_name_i .. "_name"].caption = res_disp[i]["name"]
                disp[research_name_i .. "_target"].caption = res_disp[i]["target"]
                disp[research_name_i .. "_attempt"].caption = res_disp[i]["attempt"]
                disp[research_name_i .. "_difference"].caption = res_disp[i]["difference"]
                disp[research_name_i .. "_difference"].style.font_color = res_disp[i]["color"]
            end
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
