--[[-- Commands - Rcon
System command which runs arbitrary code within a custom (not sandboxed) environment

--- Get the names of all online players, using rcon
/_system-rcon local names = {}; for index, player in pairs(game.connected_player) do names[index] = player.name end; return names;

--- Get the names of all online players, using clustorio ipcs
/_system-rcon local names = {}; for index, player in pairs(game.connected_player) do names[index] = player.name end; ipc("online-players", names);
]]

local ExpUtil = require("modules/exp_util")
local Async = require("modules/exp_util/async")
local Storage = require("modules/exp_util/storage")

local Commands = require("modules/exp_commands") --- @class Commands

local rcon_env = {} --- @type table<string, any>
local rcon_static = {} --- @type table<string, any>
local rcon_dynamic = {} --- @type table<string, ExpCommand.RconDynamic>
setmetatable(rcon_static, { __index = _G })
setmetatable(rcon_env, { __index = rcon_static })

--- Some common static values which can be added now
--- @diagnostic disable: name-style-check
rcon_static.Async = Async
rcon_static.ExpUtil = ExpUtil
rcon_static.Commands = Commands
rcon_static.print = Commands.print
--- @diagnostic enable: name-style-check

--- Some common callback values which are useful when a player uses the command
--- @alias ExpCommand.RconDynamic fun(player: LuaPlayer?): any

function rcon_dynamic.player(player) return player end

function rcon_dynamic.surface(player) return player and player.surface end

function rcon_dynamic.force(player) return player and player.force end

function rcon_dynamic.position(player) return player and player.position end

function rcon_dynamic.entity(player) return player and player.selected end

function rcon_dynamic.tile(player) return player and player.surface.get_tile(player.position.x, player.position.y) end

--- The rcon env is saved between command runs to prevent desyncs
Storage.register(rcon_env, function(tbl)
    rcon_env = setmetatable(tbl, { __index = rcon_static })
end)

--- Static values can be added to the rcon env which are not stored in global such as modules
--- @param name string Name of the value as it will appear in the rcon environment
--- @param value any Value it is have
function Commands.add_rcon_static(name, value)
    ExpUtil.assert_not_runtime()
    rcon_static[name] = value
end

--- Callback values can be added to the rcon env, these are called on each invocation and should return one value
--- @param name string Name of the value as it will appear in the rcon environment
--- @param callback ExpCommand.RconDynamic Callback called to get the current value
function Commands.add_rcon_dynamic(name, callback)
    ExpUtil.assert_not_runtime()
    rcon_dynamic[name] = callback
end

Commands.new("_rcon", { "exp-commands_rcon.description" })
    :argument("invocation", { "exp-commands_rcon.arg-invocation" }, Commands.types.string)
    :enable_auto_concatenation()
    :add_flags{ "system_only" }
    :register(function(player, invocation_string)
        --- @cast invocation_string string

        -- Construct the environment the command will run within
        local env = setmetatable({}, { __index = rcon_env, __newindex = rcon_env })
        for name, callback in pairs(rcon_dynamic) do
            local _, rtn = pcall(callback, player.index > 0 and player or nil)
            rawset(env, name, rtn)
        end

        -- Compile and run the invocation string
        local invocation, compile_error = load(invocation_string, "rcon-invocation", "t", env)
        if compile_error then
            return Commands.status.invalid_input(compile_error)
        else
            --- @cast invocation -nil
            local success, rtn = xpcall(invocation, debug.traceback)
            if success == false then
                return Commands.status.error(rtn)
            else
                return Commands.status.success(rtn)
            end
        end
    end)
