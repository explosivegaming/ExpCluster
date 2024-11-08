--[[-- Commands - VLayer
Adds a virtual layer to store power to save space.
]]

local Commands = require("modules/exp_commands")
local vlayer = require("modules.exp_legacy.modules.control.vlayer")

--- Print all vlayer information
Commands.new("vlayer-info", { "exp-commands_vlayer.description" })
    :register(function(player)
        local index = 3
        local response = { "", "exp-commands_vlayer.title" } --- @type LocalisedString
        for title, value in pairs(vlayer.get_circuits()) do
            response[index] = { "exp-commands_vlayer.result", title, value }
            index = index + 1
        end
        return Commands.status.success(response)
    end)
