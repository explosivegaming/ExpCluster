--[[-- Command Module - IPC
System command which sends an object to the clustorio api, should be used for debugging / echo commands
@commands _system-ipc

@usage-- Send a message on your custom channel, message is a json string
/_ipc myChannel { "myProperty": "foo", "playerName": "Cooldude2606" }
]]

local Commands = require("modules/exp_commands")
local Clustorio = require("modules/clusterio/api")

Commands.new("_ipc", "Send an IPC message on the selected channel")
    :add_flags{ "system_only" }
    :enable_auto_concatenation()
    :argument("channel", "string")
    :argument("message", "string")
    :register(function(_, channel, message)
        local tbl = game.json_to_table(message)
        if tbl == nil then
            return Commands.status.invalid_input("Invalid json string")
        else
            Clustorio.send_json(channel, tbl)
            return Commands.status.success()
        end
    end)
