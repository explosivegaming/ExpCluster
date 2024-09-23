--- Adds a virtual layer to store power to save space.
-- @commands Vlayer

local Commands = require 'expcore.commands' --- @dep expcore.commands
require 'config.expcore.command_general_parse'
local vlayer = require 'modules.control.vlayer'

Commands.new_command('vlayer-info', {'vlayer.description-vi'}, 'Vlayer Info')
:register(function(_)
    local c = vlayer.get_circuits()

    for k, v in pairs(c) do
        Commands.print(v .. ' : ' .. k)
    end
end)
