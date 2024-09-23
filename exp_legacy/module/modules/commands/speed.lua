--[[-- Commands Module - Set game speed
    - Adds a command that allows changing game speed
    @commands Set game speed
]]

local Commands = require 'expcore.commands' --- @dep expcore.commands
require 'config.expcore.command_general_parse'

Commands.new_command('game-speed', {'expcom-speed.description'}, 'Set game speed')
:add_param('amount', 'number-range', 0.2, 8)
:set_flag('admin_only')
:register(function(player, amount)
    game.speed = math.round(amount, 3)
    game.print{'expcom-speed.result', player.name, string.format('%.3f', amount)}
    return Commands.success
end)
