--[[-- Test environment for module/control.lua
Extends the shared stubs with a fresh copy of the reports module, a stub of
the exp_util functions it uses, and helpers to build the payloads the
instance plugin sends.

Run as a chunk by test/lua/runner.js, receiving the shared folder. The suite
returned here becomes `...` in each test file.
]]

local shared_root = ... --- @type string
local source = assert(debug.getinfo(1, "S")).source:gsub("\\", "/")
local plugin_root = assert(source:match("^@(.*)/test/module/env%.lua$"))

local Framework = assert(loadfile(shared_root .. "/framework.lua"))() --- @type Framework

--- A stubbed player which also carries the admin flag the module reads
--- @class ExpReports.TestPlayer : Stubs.Player
--- @field admin boolean

--- The environment given to each test: the stubs extended with a fresh copy
--- of the reports module and the fixture helpers
--- @class ExpReports.TestEnv : Stubs
--- @field Reports ExpReports A fresh copy of the reports module
--- @field add_player fun(name: string, is_connected: boolean?, is_admin: boolean?): ExpReports.TestPlayer
--- @field report fun(player_name: string, by_player_name: string, reason: string?): ExpReports.Report A report as the controller sends it

return Framework.suite(function(env)
    --- @cast env ExpReports.TestEnv
    env.extend_requires{
        ["modules/exp_util"] = {
            format_player_name_locale = function(name) return name end,
            color = { orange_red = "orange_red" },
        },
    }
    env.Reports = assert(loadfile(plugin_root .. "/module/control.lua"))() --- @type ExpReports

    -- The module reads player.admin, which the strict stub raises on unless it is set
    local add_player = env.add_player
    function env.add_player(name, is_connected, is_admin)
        local player = add_player(name, is_connected) --[[@as ExpReports.TestPlayer]]
        player.admin = is_admin == true
        return player
    end

    local next_id = 0
    function env.report(player_name, by_player_name, reason)
        next_id = next_id + 1
        return {
            id = next_id,
            player_name = player_name,
            by_player_name = by_player_name,
            reason = reason or "griefing",
            instance_name = "test",
            updated_at_ms = 1000,
        }
    end

    return env
end)
