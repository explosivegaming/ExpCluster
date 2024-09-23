--[[-- Commands Module - Bot queue
    - Adds a command that allows changing bot queue
    @commands Bot Queue
]]

local Commands = require 'expcore.commands' --- @dep expcore.commands
require 'config.expcore.command_general_parse'

Commands.new_command('bot-queue-get', {'expcom-bot-queue.description-get'}, 'Get bot queue')
:set_flag('admin_only')
:register(function(player)
    local s = player.force.max_successful_attempts_per_tick_per_construction_queue
    local f = player.force.max_failed_attempts_per_tick_per_construction_queue
    return Commands.success{'expcom-bot-queue.result', player.name, s, f}
end)

Commands.new_command('bot-queue-set', {'expcom-bot-queue.description-set'}, 'Set bot queue')
:add_param('amount', 'integer-range', 1, 20)
:set_flag('admin_only')
:register(function(player, amount)
    player.force.max_successful_attempts_per_tick_per_construction_queue = 3 * amount
    player.force.max_failed_attempts_per_tick_per_construction_queue = 1 * amount
    game.print{'expcom-bot-queue.result', player.name, 3 * amount, 1 * amount}
    return Commands.success
end)
