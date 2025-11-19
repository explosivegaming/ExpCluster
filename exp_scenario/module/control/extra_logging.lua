--[[-- Addon Logging
Log some extra events to a separate file
]]

local config = require("modules.exp_legacy.config.logging")
local config_res = require("modules.exp_legacy.config.research")

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
        local force = event.cargo_pod.force
        if force.rockets_launched >= config.rocket_launch_display_rate and force.rockets_launched % config.rocket_launch_display_rate == 0 then
            add_log_line("[ROCKET]", force.rockets_launched, "rockets launched")
        elseif config.rocket_launch_display[force.rockets_launched] then
            add_log_line("[ROCKET]", force.rockets_launched, "rockets launched")
        end
    end
end

--- @param event EventData.on_pre_player_died
local function on_pre_player_died(event)
    local player = assert(game.get_player(event.player_index))
    local cause = event.cause
    if cause then
        local by_player = event.cause.player
        add_log_line("[DEATH]", player.name, "died because of", by_player and by_player.name or event.cause.name)
    else
        add_log_line("[DEATH]", player.name, "died because of unknown reason")
    end
end

--- @param event EventData.on_research_finished
local function on_research_finished(event)
    if event.by_script then
        return
    end

    local inf_research_level = config_res.inf_res[config_res.mod_set][event.research.name]
    if inf_research_level and event.research.level >= inf_research_level then
        add_log_line_locale{ "", "[RES] ", event.research.prototype.localised_name, " at level ", event.research.level - 1, "has been researched\n" }
    else
        add_log_line_locale{ "", "[RES] ", event.research.prototype.localised_name, "has been researched\n" }
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
    add_log_line("[LEAVE]", game.players[event.player_index].name, config.disconnect_reason[event.reason])
end

local e = defines.events

return {
    events = {
        [e.on_cargo_pod_finished_ascending] = on_cargo_pod_finished_ascending,
        [e.on_pre_player_died] = on_pre_player_died,
        [e.on_research_finished] = on_research_finished,
        [e.on_player_joined_game] = on_player_joined_game,
        [e.on_player_left_game] = on_player_left_game,
    }
}
