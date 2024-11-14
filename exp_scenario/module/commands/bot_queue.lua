--[[-- Commands - Bot queue
Adds a command that allows viewing and changing the construction queue limits
]]

local Commands = require("modules/exp_commands")

--- Get / Set the current values for the bot queue
Commands.new("set-bot-queue", { "exp-commands_bot-queue.description" })
    :optional("amount", { "exp-commands_bot-queue.arg-amount" }, Commands.types.integer_range(1, 20))
    :add_aliases{ "bot-queue" }
    :add_flags{ "admin_only" }
    :register(function(player, amount)
        if amount then
            player.force.max_successful_attempts_per_tick_per_construction_queue = 3 * amount
            player.force.max_failed_attempts_per_tick_per_construction_queue = 5 * amount
            game.print{
                "exp-commands_bot-queue.set",
                player.force.max_successful_attempts_per_tick_per_construction_queue,
                player.force.max_failed_attempts_per_tick_per_construction_queue,
            }
            return Commands.status.success()
        end

        return Commands.status.success{
            "exp-commands_bot-queue.get",
            player.force.max_successful_attempts_per_tick_per_construction_queue,
            player.force.max_failed_attempts_per_tick_per_construction_queue,
        }
    end)
