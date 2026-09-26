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

--- The environment given to each test: the stubs extended with a fresh copy
--- of the reports module and the fixture helpers
--- @class ExpReports.TestEnv : Stubs
--- @field Reports ExpReports A fresh copy of the reports module
--- @field report fun(player_name: string, by_player_name: string, reason: string?): ExpReports.Report A report as the controller sends it

return Framework.suite(function(env)
    --- @cast env ExpReports.TestEnv
    env.extend_requires{
        ["modules/exp_util"] = {
            format_player_name_locale = function(player)
                assert(type(player) == "table", "format_player_name_locale takes a LuaPlayer")
                return player.name
            end,
            format_rich_text_color_locale = function(message) return message end,
            color = { orange_red = "orange_red", white = "white" },
        },
    }
    env.Reports = assert(loadfile(plugin_root .. "/module/control.lua"))() --- @type ExpReports

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
