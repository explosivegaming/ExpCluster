--[[-- Test environment for module/features.lua
Extends the shared stubs with a fresh copy of the features module and a stub
of exp_util storage which lets tests act out on_init and on_load.

Run as a chunk by test/lua/runner.js, receiving the shared folder. The suite
returned here becomes `...` in each test file.
]]

local shared_root = ... --- @type string
local source = assert(debug.getinfo(1, "S")).source:gsub("\\", "/")
local plugin_root = assert(source:match("^@(.*)/test/module/env%.lua$"))

local Framework = assert(loadfile(shared_root .. "/framework.lua"))() --- @type Framework

--- @class ExpScenario.TestEnv : Stubs
--- @field Features ExpScenario.Features A fresh copy of the features module
--- @field storage table The table registered with storage, as on_init would store it
--- @field on_load fun(tbl: table) Act out on_load with the given storage table
--- @field load_config fun(name: string): table Load module/config/<name>.lua
--- @field logged string[] Messages passed to log

return Framework.suite(function(env)
    --- @cast env ExpScenario.TestEnv
    local callback --- @type fun(tbl: table)
    env.logged = {}
    log = function(message) env.logged[#env.logged + 1] = message end
    env.extend_requires{
        ["modules/exp_util/storage"] = {
            register = function(tbl, fn)
                env.storage = tbl
                callback = fn
            end,
        },
    }

    env.Features = assert(loadfile(plugin_root .. "/module/features.lua"))()
    env.extend_requires{ ["modules/exp_scenario/features"] = env.Features }

    function env.on_load(tbl)
        env.storage = tbl
        callback(tbl)
    end

    function env.load_config(name)
        return assert(loadfile(plugin_root .. "/module/config/" .. name .. ".lua"))()
    end

    return env
end)
