--[[-- Command Module - IPC
System command which sends an object to the clustorio api, should be used for debugging / echo commands
@commands _system-ipc

--- Send a message on your custom channel, message is a json string
/_ipc myChannel { "myProperty": "foo", "playerName": "Cooldude2606" }
]]

local Commands = require("modules/exp_commands")
local Clustorio = require("modules/clusterio/api")

local json_to_table = helpers.json_to_table

Commands.new("_ipc", { "exp-commands-ipc.description" })
    :add_flags{ "system_only" }
    :enable_auto_concatenation()
    :argument("channel", { "exp-commands-ipc.arg-channel" }, Commands.types.string)
    :argument("message", { "exp-commands-ipc.arg-message" }, Commands.types.string)
    :register(function(_player, channel, message)
        local tbl = json_to_table(message)
        if tbl == nil then
            return Commands.status.invalid_input("Invalid json string")
        else
            Clustorio.send_json(channel, tbl)
            return Commands.status.success()
        end
    end)
