--[[-- Test environment for module/control.lua
Extends the shared stubs with a fresh copy of the server list module, a stub
of exp_util storage, and a helper to build the servers the instance plugin
sends.

Run as a chunk by test/lua/runner.js, receiving the shared folder. The suite
returned here becomes `...` in each test file.
]]

local shared_root = ... --- @type string
local source = assert(debug.getinfo(1, "S")).source:gsub("\\", "/")
local plugin_root = assert(source:match("^@(.*)/test/module/env%.lua$"))

local Framework = assert(loadfile(shared_root .. "/framework.lua"))() --- @type Framework

--- @class ExpServerList.TestEnv : Stubs
--- @field ServerList ExpServerList A fresh copy of the server list module
--- @field server fun(id: number, fields: table?): ExpServerList.Server A server as the controller sends it
--- @field connections table[] Calls to connect_to_server, with the player name as `to`

return Framework.suite(function(env)
    --- @cast env ExpServerList.TestEnv
    env.extend_requires{
        ["modules/exp_util/storage"] = {
            register = function() end,
        },
    }
    env.ServerList = assert(loadfile(plugin_root .. "/module/control.lua"))() --- @type ExpServerList

    function env.server(id, fields)
        local server = {
            id = id,
            name = "Server " .. id,
            short_name = "S" .. id,
            description = "",
            welcome = "",
            reset_time = "",
            hidden = false,
            mod_pack_name = "Base",
            factorio_version = "2.1.14",
            player_count = 0,
            status = "running",
            address = "localhost:" .. (34196 + id),
        }
        for key, value in pairs(fields or {}) do
            server[key] = value
        end
        return server
    end

    env.connections = {}
    local add_player = env.add_player
    function env.add_player(params)
        local player = add_player(params)
        rawset(player, "connect_to_server", function(opts)
            opts.to = player.name
            env.connections[#env.connections + 1] = opts
        end)
        return player
    end

    return env
end)
