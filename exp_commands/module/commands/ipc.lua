--[[-- Commands - IPC
System command which sends an object to the clustorio api, should be used for debugging / echo commands

--- Send a message on your custom channel, message is a json string
/_ipc myChannel { "myProperty": "foo", "playerName": "Cooldude2606" }
]]

local Commands = require("modules/exp_commands")
local Clustorio = require("modules/clusterio/api")

local json_to_table = helpers.json_to_table

Commands.add_rcon_static("Clustorio", Clustorio)
Commands.add_rcon_static("ipc", Clustorio.send_json)

Commands.new("_ipc", { "exp-commands_ipc.description" })
    :argument("channel", { "exp-commands_ipc.arg-channel" }, Commands.types.string)
    :argument("message", { "exp-commands_ipc.arg-message" }, Commands.types.string)
    :enable_auto_concatenation()
    :add_flags{ "system_only" }
    :register(function(_player, channel, message)
        --- @cast channel string
        --- @cast message string

        local tbl = json_to_table(message)
        if tbl == nil then
            return Commands.status.invalid_input("Invalid json string")
        else
            Clustorio.send_json(channel, tbl)
            return Commands.status.success()
        end
    end)
