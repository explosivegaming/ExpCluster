--[[-- Command Module - Sudo
System command to execute a command as another player using their permissions (except for permissions group actions)
@commands _system-sudo

@usage-- Run the example command as another player
-- As Cooldude2606: /repeat 5
/_system-sudo Cooldude2606 repeat 5
]]

local Commands = require("modules/exp_commands")

Commands.new("_sudo", "Run a command as another player")
:add_flags{ "system_only" }
:enable_auto_concatenation()
:argument("player", "player")
:argument("command", "string-key", Commands.registered_commands)
:argument("arguments", "string")
:register(function(_, player, command, parameter)
    return Commands._event_handler{
        name = command.name,
        tick = game.tick,
        player_index = player.index,
        parameter = parameter
    }
end)
