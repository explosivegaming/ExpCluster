--[[-- Test environment for the statistics module
Extends the shared stubs with fresh copies of module/control.lua and
module/events.lua, stubs of the exp_util functions they use, and players with
the fields the trackers read.

Run as a chunk by test/lua/runner.js, receiving the shared folder. The suite
returned here becomes `...` in each test file.
]]

local shared_root = ... --- @type string
local source = assert(debug.getinfo(1, "S")).source:gsub("\\", "/")
local plugin_root = assert(source:match("^@(.*)/test/module/env%.lua$"))

local Framework = assert(loadfile(shared_root .. "/framework.lua"))() --- @type Framework

--- Every event the module listens to, ids start after the shared stubs
local event_names = {
    "on_player_left_game", "on_player_created", "on_player_changed_position",
    "on_marked_for_deconstruction", "on_player_mined_entity", "on_entity_damaged",
    "on_entity_died", "on_rocket_launched", "on_research_finished",
    "on_built_entity", "on_chart_tag_added", "on_console_chat", "on_console_command",
    "on_picked_up_item", "on_player_built_tile", "on_player_crafted_item",
    "on_player_deconstructed_area", "on_player_died", "on_player_mined_tile",
    "on_player_used_capsule", "on_player_repaired_entity",
}

--- @class ExpPlayerStatistics.TestEnv : Stubs
--- @field Statistics ExpPlayerStatistics A fresh copy of the statistics module
--- @field handlers { events: table<number, fun(event: table)>, on_nth_tick: table<number, fun()> } From events.lua
--- @field force fun(name: string): table A force stub with the online players added to it
--- @field raise fun(name: string, event: table) Call the handler of an event by its name
--- @field add_player fun(params: ExpPlayerStatistics.TestPlayerParams): ExpPlayerStatistics.TestPlayer

--- @class ExpPlayerStatistics.TestPlayerParams : Stubs.PlayerParams
--- @field afk_time number? Defaults to 0
--- @field force string? Defaults to "player"

--- @class ExpPlayerStatistics.TestPlayer : Stubs.Player
--- @field afk_time number
--- @field force table

return Framework.suite(function(env)
    --- @cast env ExpPlayerStatistics.TestEnv
    local events = {}
    for index, name in ipairs(event_names) do
        events[name] = 10 + index
    end
    env.extend_defines{ events = events }

    env.extend_requires{
        ["modules/exp_util"] = {
            format_time_factory_locale = function(opts)
                return function(value) return { "time-" .. opts.format, value } end
            end,
        },
        ["modules/exp_util/storage"] = {
            register = function() end,
        },
        ["util"] = {
            format_number = function(value) return tostring(value) end,
        },
    }
    env.extend_requires{
        ["modules/exp_player_statistics/config"] = assert(loadfile(plugin_root .. "/module/config.lua"))(),
    }
    env.Statistics = assert(loadfile(plugin_root .. "/module/control.lua"))() --- @type ExpPlayerStatistics
    env.extend_requires{ ["modules/exp_player_statistics/control"] = env.Statistics }
    env.handlers = assert(loadfile(plugin_root .. "/module/events.lua"))()

    local forces = {}
    function env.force(name)
        local force = forces[name]
        if not force then
            force = { name = name, valid = true, connected_players = {} }
            forces[name] = force
        end
        return force
    end

    local add_player = env.add_player
    function env.add_player(params)
        local player = add_player(params) --[[@as ExpPlayerStatistics.TestPlayer]]
        local force = env.force(params.force or "player")
        rawset(player, "afk_time", params.afk_time or 0)
        rawset(player, "force", force)
        rawset(player, "object_name", "LuaPlayer")
        if player.connected then
            force.connected_players[#force.connected_players + 1] = player
        end
        return player
    end

    function env.raise(name, event)
        local id = (defines.events --[[@as table<string, number>]])[name]
        local handler = env.handlers.events[id]
        assert(handler, "no handler for " .. name)
        handler(event)
    end

    return env
end)
