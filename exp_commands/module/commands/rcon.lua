--[[-- Command Module - Rcon
System command which runs arbitrary code within a custom (not sandboxed) environment
@commands _system-rcon

@usage-- Get the names of all online players, using rcon
/_system-rcon local names = {}; for index, player in pairs(game.connected_player) do names[index] = player.name end; return names;

@usage-- Get the names of all online players, using clustorio ipcs
/_system-rcon local names = {}; for index, player in pairs(game.connected_player) do names[index] = player.name end; ipc("online-players", names);
]]

local ExpUtil = require("modules/exp_util")
local Async = require("modules/exp_util/async")
local Global = require("modules/exp_util/global")
local Commands = require("modules/exp_commands")
local Clustorio = require("modules/clusterio/api")

local rcon_env = {}
local rcon_statics = {}
local rcon_callbacks = {}
setmetatable(rcon_statics, { __index = _G })
setmetatable(rcon_env, { __index = rcon_statics })

--- Some common static values which can be added now
rcon_statics.Async = Async
rcon_statics.ExpUtil = ExpUtil
rcon_statics.Commands = Commands
rcon_statics.Clustorio = Clustorio
rcon_statics.output = Commands.print
rcon_statics.ipc = Clustorio.send_json

--- Some common callback values which are useful when a player uses the command
function rcon_callbacks.player(player) return player end
function rcon_callbacks.surface(player) return player and player.surface end
function rcon_callbacks.force(player) return player and player.force end
function rcon_callbacks.position(player) return player and player.position end
function rcon_callbacks.entity(player) return player and player.selected end
function rcon_callbacks.tile(player) return player and player.surface.get_tile(player.position) end

--- The rcon env is saved between command runs to prevent desyncs
Global.register(rcon_env, function(tbl)
    rcon_env = setmetatable(tbl, { __index = rcon_statics })
end)

--- Static values can be added to the rcon env which are not stored in global such as modules
function Commands.add_rcon_static(name, value)
    ExpUtil.assert_not_runtime()
    rcon_statics[name] = value
end

--- Callback values can be added to the rcon env, these are called on each invocation and should return one value
function Commands.add_rcon_callback(name, callback)
    ExpUtil.assert_not_runtime()
    rcon_callbacks[name] = callback
end

Commands.new("_rcon", "Execute arbitrary code within a custom environment")
:add_flags{ "system_only" }
:enable_auto_concatenation()
:argument("invocation", "string")
:register(function(player, invocation_string)
    -- Construct the environment the command will run within
    local env = setmetatable({}, { __index = rcon_env, __newindex = rcon_env })
    for name, callback in pairs(rcon_callbacks) do
        local _, rtn = pcall(callback, player.index > 0 and player or nil)
        rawset(env, name, rtn)
    end

    -- Compile and run the invocation string
    local invocation, compile_error = load(invocation_string, "rcon-invocation", "t", env)
    if compile_error then
        return Commands.status.invalid_input(compile_error)
    else
        local success, rtn = xpcall(invocation, debug.traceback)
        if success == false then
            local err = rtn:gsub('%.%.%..-/temp/currently%-playing/', '')
            return Commands.status.error(err)
        else
            return Commands.status.success(rtn)
        end
    end
end)
