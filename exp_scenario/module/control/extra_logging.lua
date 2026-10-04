--[[-- Addon Logging
Log some extra events to a separate file
]]

local Feature = require("modules/exp_scenario/features")
local research_data = require("modules/exp_scenario/config/research_data")

local feature, config = Feature.register("extra_logging", {
    file_name = "log/logging.log", -- the file the lines are written to
    rocket_launch_display_rate = 500, -- after the counts below, log every this many rockets
})

--- Rocket counts which are always logged
local rocket_launch_display = {
    [1] = true,
    [2] = true,
    [5] = true,
    [10] = true,
    [20] = true,
    [50] = true,
    [100] = true,
    [200] = true,
}

local disconnect_reason = {
    [defines.disconnect_reason.quit] = "left the game",
    [defines.disconnect_reason.dropped] = "was dropped from the game",
    [defines.disconnect_reason.reconnect] = "is reconnecting",
    [defines.disconnect_reason.wrong_input] = "was having a wrong input",
    [defines.disconnect_reason.desync_limit_reached] = "had desync limit reached",
    [defines.disconnect_reason.cannot_keep_up] = "cannot keep up",
    [defines.disconnect_reason.afk] = "was afk",
    [defines.disconnect_reason.kicked] = "was kicked",
    [defines.disconnect_reason.kicked_and_deleted] = "was kicked and deleted",
    [defines.disconnect_reason.banned] = "was banned",
    [defines.disconnect_reason.switching_servers] = "is switching servers",
}

local concat = table.concat
local write_file = helpers.write_file

--- Add a line to the log file
--- @param ... string
local function add_log_line(...)
    write_file(config.file_name, concat({ ... }, " ") .. "\n", true, 0)
end

--- Add a line to the log file
--- @param line LocalisedString
local function add_log_line_locale(line)
    write_file(config.file_name, line, true, 0)
end

--- @param event EventData.on_cargo_pod_finished_ascending
local function on_cargo_pod_finished_ascending(event)
    if event.launched_by_rocket then
        local force = event.cargo_pod.force --[[@as LuaForce]]
        if force.rockets_launched >= config.rocket_launch_display_rate and force.rockets_launched % config.rocket_launch_display_rate == 0 then
            add_log_line("[ROCKET]", force.rockets_launched, "rockets launched")
        elseif rocket_launch_display[force.rockets_launched] then
            add_log_line("[ROCKET]", force.rockets_launched, "rockets launched")
        end
    end
end

--- @param event EventData.on_pre_player_died
local function on_pre_player_died(event)
    local player = assert(game.get_player(event.player_index))
    local cause = event.cause
    if cause then
        if cause.type == "character" then
            add_log_line("[DEATH]", player.name, "died because of", assert(cause.player).name)
        else
            add_log_line("[DEATH]", player.name, "died because of", cause.name)
        end
    else
        add_log_line("[DEATH]", player.name, "died because of unknown reason")
    end
end

--- @param event EventData.on_research_finished
local function on_research_finished(event)
    if event.by_script then
        return
    end

    local inf_research_level = research_data.inf_res[research_data.mod_set][event.research.name]
    if inf_research_level and event.research.level >= inf_research_level then
        add_log_line_locale{ "", "[RES]", event.research.prototype.localised_name, " at level ", event.research.level - 1, " has been researched\n" }
    else
        add_log_line_locale{ "", "[RES]", event.research.prototype.localised_name, " has been researched\n" }
    end
end

--- @param event EventData.on_player_joined_game
local function on_player_joined_game(event)
    local player = assert(game.get_player(event.player_index))
    add_log_line("[JOIN]", player.name, "joined the game")
end

--- @param event EventData.on_player_left_game
local function on_player_left_game(event)
    local player = assert(game.get_player(event.player_index))
    add_log_line("[LEAVE]", player.name, disconnect_reason[event.reason])
end

local e = defines.events

return feature:guard{
    events = {
        [e.on_cargo_pod_finished_ascending] = on_cargo_pod_finished_ascending,
        [e.on_pre_player_died] = on_pre_player_died,
        [e.on_research_finished] = on_research_finished,
        [e.on_player_joined_game] = on_player_joined_game,
        [e.on_player_left_game] = on_player_left_game,
    },
}
