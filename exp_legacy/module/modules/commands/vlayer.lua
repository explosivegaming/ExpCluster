--- Adds a virtual layer to store power to save space.
-- @commands Vlayer

local Commands = require("modules.exp_legacy.expcore.commands") --- @dep expcore.commands
require("modules.exp_legacy.config.expcore.command_general_parse")
local vlayer = require("modules.exp_legacy.modules.control.vlayer")

Commands.new_command("vlayer-info", { "vlayer.description-vi" }, "Vlayer Info")
    :register(function(_)
        local c = vlayer.get_circuits()

        for k, v in pairs(c) do
            Commands.print(v .. " : " .. k)
        end
    end)
