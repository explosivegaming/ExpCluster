--[[-- Commands - VLayer
Adds a virtual layer to store power to save space.
]]

local Commands = require("modules/exp_commands")
local vlayer = require("modules.exp_legacy.modules.control.vlayer")

--- @class ExpCommand_vlayer.commands
local commands = {}

--- Print all vlayer information
--- @class ExpCommands_vlayer.commands.vlayer: ExpCommand
commands.vlayer = Commands.new("vlayer-info", { "exp-commands_vlayer.description" })
    :register(function(player)
        local index = 3
        local response = { "", "exp-commands_vlayer.title" } --- @type LocalisedString
        for title, value in pairs(vlayer.get_circuits()) do
            response[index] = { "exp-commands_vlayer.result", title, value }
            index = index + 1
        end
        return Commands.status.success(response)
    end)

return {
    commands = commands,
}
