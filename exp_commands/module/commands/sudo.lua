--[[-- Command Module - Sudo
System command to execute a command as another player using their permissions (except for permissions group actions)
@commands _system-sudo

--- Run the example command as another player
-- As Cooldude2606: /repeat 5
/_system-sudo Cooldude2606 repeat 5
]]

local Commands = require("modules/exp_commands")

Commands.new("_sudo", { "exp-commands-sudo.description" })
    :add_flags{ "system_only" }
    :enable_auto_concatenation()
    :argument("player", { "exp-commands-sudo.arg-player" }, Commands.types.player)
    :argument("command", { "exp-commands-sudo.arg-command" }, Commands.types.string_key(Commands.registered_commands))
    :argument("arguments", { "exp-commands-sudo.arg-arguments" }, Commands.types.string)
    :register(function(_player, player, command, parameter)
        --- @diagnostic disable-next-line: invisible
        return Commands._event_handler{
            name = command.name,
            tick = game.tick,
            player_index = player.index,
            parameter = parameter,
        }
    end)
